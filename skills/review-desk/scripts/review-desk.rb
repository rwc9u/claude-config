#!/usr/bin/env ruby
# frozen_string_literal: true

#
# review-desk.rb — Track PRs awaiting your review and run /review-pr sessions in a cmux "Reviews" workspace
#
# Usage:
#   ruby review-desk.rb watch [--interval 300] [--max-concurrent 3] [--team SLUG]...
#   ruby review-desk.rb tick [--dry-run] [--team SLUG]...
#   ruby review-desk.rb start <owner/repo#n | repo#n | n> | --all
#   ruby review-desk.rb prepare <owner/repo#n>
#   ruby review-desk.rb prune [--yes]
#   ruby review-desk.rb bots on|off|status
#   ruby review-desk.rb max-age <days>|off|status
#
# Requires: gh (GitHub CLI) authenticated, wt (worktrunk), cmux (optional)

require "json"
require "open3"
require "time"
require "optparse"
require "fileutils"
require "socket"
require "securerandom"
require "timeout"
require "uri"
require "erb"
require "rbconfig"

module ReviewDesk
  STATE_DIR = File.expand_path("~/.local/state/review-desk")
  STATE_PATH = File.join(STATE_DIR, "state.json")
  LOCK_PATH = File.join(STATE_DIR, "state.lock")
  QUEUE_PATH = File.join(STATE_DIR, "queue.md")
  CONFIG_PATH = File.join(STATE_DIR, "config.json")
  VERDICT_DIR = File.join(STATE_DIR, "verdicts")
  REPO_LOCK_DIR = File.join(STATE_DIR, "locks")
  PREPARE_ERROR = "worktree creation failed; see its tab"
  CHECKOUT_ROOT = File.expand_path("~/dev")
  SCRIPT_PATH = File.expand_path("~/.claude/skills/review-desk/scripts/review-desk.rb")
  RETENTION_SECONDS = 24 * 3600
  DEFAULT_PORT = 47_321
  REQUEST_TIMEOUT = 5
  MAX_LINE = 8192
  MAX_HEADERS = 100

  ACTIVE_STATES = %w[queued start-requested reviewing verdict-ready no-checkout].freeze
  DONE_STATES = %w[filed dropped taken].freeze
  FILTERABLE_STATES = %w[queued start-requested no-checkout].freeze
  DEFAULT_FILTERS = { "show_bots" => false, "max_age_days" => nil }.freeze
  LEGEND = {
    "queued" => ["Queued", "waiting for you to click start"],
    "start-requested" => ["Starting", "start clicked; opens a review tab when a slot frees"],
    "reviewing" => ["Reviewing", "/review-pr is running in its tab"],
    "verdict-ready" => ["Verdict ready", "review done; read the verdict and file it from the tab"],
    "filed" => ["Filed", "your review is on GitHub; a new push sends it back to Queued"],
    "taken" => ["Taken", "a teammate reviewed it for the team"],
    "dropped" => ["Dropped", "closed, merged, back to draft, or request withdrawn"],
    "no-checkout" => ["No checkout", "no `~/dev/<repo>` clone, so it can't start"],
  }.freeze

  Facts = Struct.new(
    :open, :requested, :head_sha, :reviewed_at_head, :taken_by, :checkout,
    keyword_init: true,
  )

  # Pure state machine: no gh, cmux, or filesystem access.
  module Transition
    module_function

    def call(entry, facts, verdict_ready: false)
      state = entry && entry["state"]
      return(state && "dropped") unless facts.open
      return "filed" if facts.reviewed_at_head && (state || facts.requested)
      return(facts.requested ? arrival(facts) : nil) if state.nil?

      case state
      when "verdict-ready", "filed"
        facts.requested && facts.head_sha != entry["review_head"] ? "queued" : state
      when "reviewing"
        return "verdict-ready" if verdict_ready

        facts.requested ? state : withdrawn(facts)
      when "queued", "start-requested"
        facts.requested ? state : withdrawn(facts)
      when "no-checkout"
        facts.requested ? arrival(facts) : withdrawn(facts)
      else
        facts.requested ? arrival(facts) : state
      end
    end

    def request_start(entry)
      entry["state"] == "queued" ? "start-requested" : entry["state"]
    end

    # Only a review still in flight goes back; a tick may have dropped it meanwhile.
    def prepare_failed(entry, now)
      return entry unless entry["state"] == "reviewing"

      entry.except("surface").merge("state" => "queued", "last_error" => PREPARE_ERROR,
                                    "state_changed_at" => now.iso8601)
    end

    def repo_lock_path(repo)
      File.join(REPO_LOCK_DIR, "#{repo.tr("/", "-")}.lock")
    end

    def spawn_plan(entries, max_concurrent)
      slots = max_concurrent - entries.count { |e| e["state"] == "reviewing" }
      return [] if slots <= 0

      entries
        .select { |e| e["state"] == "start-requested" }
        .sort_by { |e| e["start_requested_at"].to_s }
        .first(slots)
        .map { |e| e["key"] }
    end

    def bot_author?(author)
      return false unless author

      login = author["login"].to_s
      author["type"] == "Bot" || author["__typename"] == "Bot" || author["is_bot"] == true ||
        login.end_with?("[bot]") || login.start_with?("app/")
    end

    # In-flight and recently finished rows stay visible whatever the filters say.
    def hidden_reasons(entry, filters, now)
      return [] unless FILTERABLE_STATES.include?(entry["state"])

      reasons = []
      reasons << :bot if entry["bot"] && !filters["show_bots"]
      max_age = filters["max_age_days"]
      reasons << :age if max_age && entry["created_at"] && now - Time.parse(entry["created_at"]) > max_age * 86_400
      reasons
    end

    def visible?(entry, filters, now)
      hidden_reasons(entry, filters, now).empty?
    end

    def parse_max_age(value)
      return nil if value == "off"

      days = value.to_s.delete_suffix("d")
      raise ArgumentError, "max-age takes a number of days or 'off'" unless days.match?(/\A\d+\z/)

      days.to_i
    end

    def arrival(facts)
      facts.checkout ? "queued" : "no-checkout"
    end

    def withdrawn(facts)
      facts.taken_by ? "taken" : "dropped"
    end
  end

  # Pure request routing for the watcher's local listener.
  module Http
    module_function

    START_PATH = %r{\A/start/([\w.-]+)/([\w.-]+)/(\d+)\z}

    def route(request_line, token)
      method, target = request_line.to_s.split(" ", 3)
      return [:bad_request] unless method == "GET" && target&.start_with?("/")

      path, query = target.split("?", 2)
      return [:forbidden] unless token_matches?(query_param(query, "t"), token)
      return [:start_all] if path == "/start-all"

      match = START_PATH.match(path)
      match ? [:start, "#{match[1]}/#{match[2]}##{match[3]}"] : [:not_found]
    end

    def query_param(query, name)
      URI.decode_www_form(query.to_s).to_h[name]
    rescue ArgumentError
      nil
    end

    def token_matches?(given, token)
      return false if given.to_s.empty? || token.to_s.empty? || given.bytesize != token.bytesize

      given.bytes.zip(token.bytes).sum { |a, b| a ^ b }.zero?
    end
  end

  class GhError < StandardError; end

  class Desk
    SEARCH_FIELDS = "number,repository,isDraft,author"
    PR_FIELDS = <<~GRAPHQL.tr("\n", " ")
      number title url state isDraft createdAt baseRefName headRefName headRefOid author { __typename login }
      reviewRequests(first: 30) { nodes { requestedReviewer {
        __typename ... on User { login } ... on Team { slug organization { login } } } } }
      latestReviews(first: 30) { nodes { author { login } state submittedAt commit { oid } } }
    GRAPHQL
    GRAPHQL_CHUNK = 25

    attr_reader :username, :max_concurrent, :teams_filter, :dry_run

    def initialize(username:, max_concurrent: 3, teams_filter: [], dry_run: false, workspace: nil)
      @username = username
      @max_concurrent = max_concurrent
      @teams_filter = teams_filter
      @dry_run = dry_run
      @workspace_override = workspace
      @cmux_warned = false
      @lock_mutex = Mutex.new
    end

    def watch(interval, port: DEFAULT_PORT)
      $stdout.sync = true
      server = open_listener(port)
      @token = SecureRandom.hex(16)
      locked do |state|
        state["workspace_ref"] = @workspace_override || ENV["CMUX_WORKSPACE_ID"] || state["workspace_ref"]
        state["listener"] = { "port" => port, "token" => @token, "pid" => Process.pid }
      end
      Thread.new { serve(server) }
      loop do
        tick
        sleep interval
      end
    end

    # Fetch outside the lock so start clicks never wait on GitHub; merge into a fresh read of state.
    def tick
      @filters = filters
      snapshot = load_state
      teams = fetch_teams
      @my_teams = teams || snapshot["my_teams"] || []
      fetched = begin
        candidates = search_requested
        [candidates, fetch_facts(candidates, snapshot["prs"])]
      rescue GhError => e
        warn "[#{Time.now.utc.iso8601}] gh failed, keeping previous state: #{e.message}"
        nil
      end
      locked do |state|
        state["my_teams"] = teams if teams
        fetched ? merge_tick(state, *fetched) : render(state, Time.now.utc)
      end
    end

    def start(targets, all: false)
      return start_all if all

      snapshot = load_state["prs"]
      targets.filter_map { |t| resolve(snapshot, t) }.each { |key| puts start_one(key).first }
    end

    def bots(mode)
      return puts("Bot PRs are #{filters["show_bots"] ? "shown" : "hidden"}.") unless %w[on off].include?(mode)

      update_filters("show_bots" => mode == "on")
      puts "Bot PRs #{mode == "on" ? "shown" : "hidden"}."
      tick
    end

    def max_age(value)
      if value.nil? || value == "status"
        days = filters["max_age_days"]
        return puts(days ? "Showing PRs created in the last #{days}d." : "Showing PRs of all ages.")
      end

      days = Transition.parse_max_age(value)
      update_filters("max_age_days" => days)
      puts(days ? "Hiding PRs created more than #{days}d ago." : "Showing PRs of all ages.")
      tick
    end

    def prune(yes:)
      state = load_state
      entries = state["prs"].values.select { |e| DONE_STATES.include?(e["state"]) }
      commands = entries.filter_map { |e| prune_command(e) }
      if commands.empty?
        puts "Nothing to prune."
        return
      end

      commands.each do |cmd|
        puts cmd.join(" ")
        next unless yes

        _, err, status = Open3.capture3(*cmd)
        warn "  failed: #{err.strip}" unless status.success?
      end
      puts "", "Re-run with --yes to remove these worktrees." unless yes
    end

    # Concurrent `wt switch` runs in one repo race on .git/config; flock frees itself if the tab dies.
    def prepare(key)
      repo, number = key.split("#")
      FileUtils.mkdir_p(REPO_LOCK_DIR)
      created = File.open(Transition.repo_lock_path(repo), File::RDWR | File::CREAT) do |lock|
        lock.flock(File::LOCK_EX)
        system("wt", "-C", checkout_dir(repo), "switch", "pr:#{number}", "--no-cd")
      end
      return true if created

      locked do |state|
        state["prs"][key] = Transition.prepare_failed(state["prs"][key], Time.now.utc) if state["prs"][key]
        render(state, Time.now.utc)
      end
      puts "#{key} went back to Queued; start it again from the dashboard."
      false
    end

    private

    def merge_tick(state, candidates, facts_by_key)
      now = Time.now.utc
      arrivals = apply_transitions(state["prs"], candidates, facts_by_key, now)
      notify_arrivals(state, arrivals)
      state["last_tick_at"] = now.iso8601
      spawn_and_render(state, now)
      puts "[#{now.getlocal.strftime("%H:%M")}] #{summary_line(visible_entries(state, now)).delete("*")}"
    end

    def spawn_and_render(state, now)
      spawn_pending(state, now)
      render(state, now)
      set_status(state)
    end

    # Returns [message, pr_url]. The PR check runs before the lock so a slow gh call never blocks a tick.
    def start_one(key)
      @filters = filters
      live = check_pr(key) if load_state["prs"].dig(key, "state") == "queued"
      locked do |state|
        entry = state["prs"][key]
        next ["Not tracking #{key}.", nil] unless entry

        refusal = live && live_refusal(entry, live)
        if refusal
          render(state, Time.now.utc)
          next [refusal, entry["url"]]
        end

        entry["head_sha"] = live["headRefOid"] if live&.dig("headRefOid")
        unless mark_start(entry)
          next ["#{short_ref(entry)} is #{entry["state"]}; only queued PRs can be started.", entry["url"]]
        end

        spawn_and_render(state, Time.now.utc)
        ["Started #{short_ref(entry)} (#{start_outcome(entry)}).", entry["url"]]
      end
    end

    def start_all
      @filters = filters
      locked do |state|
        started = startable_keys(state["prs"]).count { |key| mark_start(state["prs"][key]) }
        spawn_and_render(state, Time.now.utc)
        "Started #{started} queued PR#{"s" unless started == 1}.".tap { |message| puts message }
      end
    end

    def check_pr(key)
      repo, number = key.split("#")
      owner, name = repo.split("/", 2)
      query = "query { repository(owner: #{owner.to_json}, name: #{name.to_json}) " \
              "{ pullRequest(number: #{number.to_i}) { state isDraft headRefOid } } }"
      graphql(query).dig("repository", "pullRequest")
    rescue GhError => e
      warn "Could not check #{key} (#{e.message}); starting from cached state."
      nil
    end

    def live_refusal(entry, live)
      reason = if live["state"] != "OPEN" then live["state"].downcase
      elsif live["isDraft"] then "a draft"
      end
      return unless reason

      entry.delete("last_error")
      entry.merge!("state" => "dropped", "state_changed_at" => Time.now.utc.iso8601)
      "#{short_ref(entry)} is #{reason}; not starting it."
    end

    def apply_transitions(entries, candidates, facts_by_key, now)
      arrivals = 0
      facts_by_key.each do |key, raw|
        entry = entries[key]
        facts = build_facts(raw, candidates.include?(key))
        new_state = Transition.call(entry, facts, verdict_ready: entry ? verdict_ready?(entry) : false)
        next if new_state.nil?

        entry ||= entries[key] = { "key" => key, "first_seen_at" => now.iso8601 }
        old_state = entry["state"]
        refresh_entry(entry, raw, facts, candidates[key])
        next if new_state == old_state

        enter_state(entry, old_state, new_state, facts, now)
        arrivals += 1 if new_state == "queued" && Transition.visible?(entry, @filters, now)
      end
      arrivals
    end

    def enter_state(entry, old_state, new_state, facts, now)
      entry.delete("last_error")
      case new_state
      when "queued"
        retire_verdict(entry) if %w[verdict-ready filed].include?(old_state)
        entry.delete("surface")
      when "verdict-ready"
        entry["review_head"] = verdict_head(entry) || entry["review_head"]
        announce_verdict(entry)
      when "filed"
        entry["review_head"] = facts.head_sha
      when "taken"
        entry["taken_by"] = facts.taken_by
      end
      entry["state"] = new_state
      entry["state_changed_at"] = now.iso8601
    end

    def refresh_entry(entry, raw, facts, search_author)
      pr = raw[:pr]
      entry.merge!(
        "bot" => Transition.bot_author?(search_author) || Transition.bot_author?(pr["author"]),
        "repo" => raw[:repo],
        "number" => pr["number"],
        "title" => pr["title"],
        "url" => pr["url"],
        "author" => pr.dig("author", "login"),
        "base" => pr["baseRefName"],
        "default_branch" => raw[:default_branch],
        "head_ref" => pr["headRefName"],
        "head_sha" => facts.head_sha,
        "created_at" => pr["createdAt"],
        "direct" => raw[:direct],
        "teams" => raw[:teams],
      )
    end

    def build_facts(raw, in_search)
      pr = raw[:pr]
      counted = teams_filter.empty? || raw[:direct] || raw[:teams].intersect?(teams_filter)
      requested = in_search && !pr["isDraft"] && counted
      Facts.new(
        open: pr["state"] == "OPEN",
        requested: requested,
        head_sha: pr["headRefOid"],
        reviewed_at_head: raw[:reviewed_at_head],
        taken_by: raw[:taken_by],
        checkout: Dir.exist?(checkout_dir(raw[:repo])),
      )
    end

    def mark_start(entry)
      new_state = Transition.request_start(entry)
      if new_state == entry["state"]
        warn "#{entry["key"]} is #{entry["state"]}; only queued PRs can be started."
        return false
      end

      entry["state"] = new_state
      entry["start_requested_at"] = Time.now.utc.iso8601
      entry.delete("last_error")
      puts "#{entry["key"]} → start-requested"
      true
    end

    def startable_keys(entries)
      now = Time.now.utc
      entries.select { |_, e| e["state"] == "queued" && Transition.visible?(e, filters, now) }.keys
    end

    def resolve(entries, target)
      matches = entries.keys.select do |key|
        key.casecmp?(target) ||
          key.split("/", 2).last.casecmp?(target) ||
          key.end_with?("##{target.delete_prefix("#")}")
      end
      return matches.first if matches.size == 1

      warn(matches.empty? ? "No tracked PR matches #{target}." : "#{target} is ambiguous: #{matches.join(", ")}")
      nil
    end

    # --- GitHub ---

    def search_requested
      output = gh!(
        "search", "prs",
        "--review-requested=#{username}",
        "--state=open",
        "--archived=false",
        "--limit", "200",
        "--json", SEARCH_FIELDS,
      )
      parse_json(output)
        .reject { |pr| pr["isDraft"] || pr.dig("author", "login")&.casecmp?(username) }
        .to_h { |pr| ["#{pr.dig("repository", "nameWithOwner")}##{pr["number"]}", pr["author"] || {}] }
    end

    def fetch_teams
      output, status = Open3.capture2(
        "gh", "api", "user/teams", "--paginate",
        "--jq", ".[] | .organization.login + \"/\" + .slug",
      )
      return output.split("\n") if status.success?

      warn "Could not list your teams; using the cached list."
      nil
    end

    def fetch_facts(candidates, entries)
      keys = (candidates.keys + entries.select { |_, e| ACTIVE_STATES.include?(e["state"]) }.keys).uniq
      keys.each_slice(GRAPHQL_CHUNK).each_with_object({}) do |chunk, facts|
        facts.merge!(fetch_chunk(chunk))
      end
    end

    def fetch_chunk(keys)
      by_repo = keys.group_by { |key| key.split("#").first }
      fragments = by_repo.each_with_index.map do |(repo, repo_keys), ri|
        owner, name = repo.split("/", 2)
        prs = repo_keys.each_with_index.map do |key, pi|
          "p#{pi}: pullRequest(number: #{key.split("#").last.to_i}) { #{PR_FIELDS} }"
        end
        "r#{ri}: repository(owner: #{owner.to_json}, name: #{name.to_json}) " \
          "{ defaultBranchRef { name } #{prs.join(" ")} }"
      end
      data = graphql("query { #{fragments.join(" ")} }")

      by_repo.each_with_index.each_with_object({}) do |((repo, repo_keys), ri), facts|
        repo_data = data["r#{ri}"] or next
        repo_keys.each_with_index do |key, pi|
          pr = repo_data["p#{pi}"] or next
          facts[key] = summarize(repo, pr, repo_data.dig("defaultBranchRef", "name"))
        end
      end
    end

    def summarize(repo, pr, default_branch)
      reviewers = pr.dig("reviewRequests", "nodes").map { |n| n["requestedReviewer"] }.compact
      team_requests = reviewers.select { |r| r["__typename"] == "Team" }
      mine = team_requests.select { |t| @my_teams.include?("#{t.dig("organization", "login")}/#{t["slug"]}") }
      submitted = pr.dig("latestReviews", "nodes").reject { |r| %w[PENDING DISMISSED].include?(r["state"]) }
      author = pr.dig("author", "login")
      mine_reviews, others = submitted.partition { |r| r.dig("author", "login")&.casecmp?(username) }
      latest_other = others.reject { |r| r.dig("author", "login") == author }.max_by { |r| r["submittedAt"].to_s }

      {
        repo: repo,
        pr: pr,
        default_branch: default_branch,
        direct: reviewers.any? { |r| r["login"]&.casecmp?(username) },
        teams: (mine.empty? ? team_requests : mine).map { |t| t["slug"] },
        reviewed_at_head: mine_reviews.any? { |r| r.dig("commit", "oid") == pr["headRefOid"] },
        taken_by: latest_other && "#{latest_other.dig("author", "login")} (#{review_state_label(latest_other)})",
      }
    end

    def review_state_label(review)
      review["state"].downcase.tr("_", " ")
    end

    # A deleted or inaccessible PR makes gh exit non-zero but still returns data for the rest.
    def graphql(query)
      output, err, status = Open3.capture3("gh", "api", "graphql", "-f", "query=#{query}")
      data = begin
        JSON.parse(output)["data"]
      rescue JSON::ParserError
        nil
      end
      raise GhError, "gh api graphql: #{err.strip[0, 200]}" unless data

      warn "gh api graphql reported errors: #{err.strip[0, 200]}" unless status.success?
      data
    end

    def gh!(*args)
      output, err, status = Open3.capture3("gh", *args)
      raise GhError, "gh #{args.first(2).join(" ")}: #{err.strip[0, 200]}" unless status.success?

      output
    end

    def parse_json(output)
      JSON.parse(output)
    rescue JSON::ParserError => e
      raise GhError, "unparseable gh output: #{e.message[0, 120]}"
    end

    # --- Verdicts ---

    def verdict_path(entry)
      File.join(VERDICT_DIR, "#{entry["key"].tr("/#", "--")}.md")
    end

    def verdict_ready?(entry)
      path = verdict_path(entry)
      File.exist?(path) && entry["spawned_at"] && File.mtime(path) >= Time.parse(entry["spawned_at"])
    end

    def verdict_head(entry)
      head = File.foreach(verdict_path(entry)).first(5).grep(/\Ahead:/).first&.split(":", 2)&.last&.strip
      head if head&.match?(/\A\h{40}\z/)
    end

    def verdict_label(entry)
      line = File.foreach(verdict_path(entry)).first(5).grep(/\Averdict:/).first
      line&.split(":", 2)&.last&.strip
    rescue Errno::ENOENT
      nil
    end

    def retire_verdict(entry)
      path = verdict_path(entry)
      return unless File.exist?(path)

      stale = path.sub(/\.md\z/, "-#{entry["review_head"].to_s[0, 7]}.md")
      File.rename(path, stale)
      entry["stale_verdict"] = stale
    end

    # --- Spawning ---

    def spawn_pending(state, now)
      plan = Transition.spawn_plan(state["prs"].values, max_concurrent)
      return if plan.empty?
      return warn("Dry run: would start #{plan.join(", ")}") if dry_run
      return unless cmux_available?(state)

      plan.each do |key|
        entry = state["prs"][key]
        surface = spawn_tab(state, entry)
        next unless surface

        entry.merge!(
          "state" => "reviewing", "surface" => surface, "review_head" => entry["head_sha"],
          "spawned_at" => now.iso8601, "state_changed_at" => now.iso8601,
        )
      end
    end

    def spawn_tab(state, entry)
      workspace = state["workspace_ref"]
      command = review_command(entry)
      pane = state["review_pane"] if pane_exists?(workspace, state["review_pane"])
      args = if pane
        ["new-surface", "--workspace", workspace, "--pane", pane, "--type", "terminal"]
      else
        ["new-pane", "--workspace", workspace, "--type", "terminal", "--direction", "right"]
      end
      result = cmux_json(*args, "--command", command, "--focus", "false")
      return warn("Could not open a review tab for #{entry["key"]}") unless result

      state["review_pane"] = result["pane_ref"]
      tab = "#{entry["repo"].split("/").last}##{entry["number"]}"
      cmux("rename-tab", "--workspace", workspace, "--surface", result["surface_ref"], tab)
      result["surface_ref"]
    end

    def review_command(entry)
      prompt = "/review-pr #{entry["number"]} low"
      run = if worktree_exists?(entry)
        "-x sh -- -c #{sh_quote("git pull --ff-only && exec claude #{sh_quote(prompt)}")}"
      else
        "-x claude -- #{sh_quote(prompt)}"
      end
      "#{sh_quote(RbConfig.ruby)} #{sh_quote(SCRIPT_PATH)} prepare #{sh_quote(entry["key"])} && " \
        "cd #{sh_quote(checkout_dir(entry["repo"]))} && REVIEW_DESK_DIR=#{sh_quote(VERDICT_DIR)} " \
        "wt switch pr:#{entry["number"]} #{run}"
    end

    def worktree_exists?(entry)
      return false unless entry["head_ref"]

      output, status = Open3.capture2("git", "-C", checkout_dir(entry["repo"]), "worktree", "list", "--porcelain")
      status.success? && output.include?("branch refs/heads/#{entry["head_ref"]}\n")
    end

    def prune_command(entry)
      return unless worktree_exists?(entry)

      ["wt", "-C", checkout_dir(entry["repo"]), "remove", entry["head_ref"]]
    end

    # --- cmux ---

    def cmux_available?(state)
      reason = if dry_run then "dry run"
      elsif ENV["CMUX_SOCKET_PATH"].to_s.empty? then "CMUX_SOCKET_PATH is unset"
      elsif !command_on_path?("cmux") then "cmux is not on PATH"
      elsif state["workspace_ref"].to_s.empty? then "no Reviews workspace recorded (run watch, or pass --workspace)"
      end
      return true unless reason

      warn "Skipping cmux calls: #{reason}." unless @cmux_warned
      @cmux_warned = true
      false
    end

    def command_on_path?(name)
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
    end

    def cmux(*args)
      _, err, status = Open3.capture3({ "CMUX_QUIET" => "1" }, "cmux", *args)
      warn "cmux #{args.first} failed: #{err.strip}" unless status.success?
      status.success?
    end

    def cmux_json(*args)
      output, err, status = Open3.capture3({ "CMUX_QUIET" => "1" }, "cmux", "--json", *args)
      return JSON.parse(output) if status.success?

      warn "cmux #{args.first} failed: #{err.strip}"
      nil
    rescue JSON::ParserError
      nil
    end

    def pane_exists?(workspace, pane)
      return false unless pane

      panes = cmux_json("list-panes", "--workspace", workspace)
      panes && panes["panes"].any? { |p| p["ref"] == pane }
    end

    def notify_arrivals(state, count)
      return if count.zero? || !cmux_available?(state)

      body = "#{count} PR#{"s" if count > 1} waiting to be started"
      cmux("notify", "--title", "Review desk", "--body", body, "--workspace", state["workspace_ref"])
    end

    def announce_verdict(entry)
      @verdicts_to_announce ||= []
      @verdicts_to_announce << entry
    end

    def set_status(state)
      announcements = @verdicts_to_announce || []
      @verdicts_to_announce = []
      return unless cmux_available?(state)

      workspace = state["workspace_ref"]
      announcements.each do |entry|
        body = "#{entry["repo"].split("/").last}##{entry["number"]}: #{verdict_label(entry) || "verdict ready"}"
        cmux("notify", "--title", "Review ready", "--body", body,
             "--workspace", workspace, "--surface", entry["surface"].to_s)
        cmux("trigger-flash", "--workspace", workspace, "--surface", entry["surface"].to_s)
      end
      counts = visible_entries(state, Time.now.utc).map { |e| e["state"] }.tally
      queued = counts.fetch("queued", 0) + counts.fetch("start-requested", 0)
      status = "#{counts.fetch("verdict-ready", 0)} ready · " \
               "#{counts.fetch("reviewing", 0)} reviewing · #{queued} queued"
      cmux("set-status", "reviews", status, "--workspace", workspace)
    end

    # --- Listener ---

    def open_listener(port)
      TCPServer.new("127.0.0.1", port)
    rescue Errno::EADDRINUSE
      abort "Port #{port} is already in use. Stop the other watcher or pass --port; links must stay stable."
    end

    def serve(server)
      loop do
        client = server.accept
        begin
          handle_request(client)
        rescue StandardError => e
          warn "listener: #{e.class}: #{e.message}"
        ensure
          client.close
        end
      end
    end

    def handle_request(client)
      request_line = Timeout.timeout(REQUEST_TIMEOUT) { read_head(client) }
      status, body = respond(Http.route(request_line, @token))
      client.write("HTTP/1.1 #{status}\r\nContent-Type: text/html; charset=utf-8\r\n" \
                   "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
    rescue Timeout::Error
      nil
    end

    # Headers are read and discarded so the browser sees a clean response; bodies are never read.
    def read_head(client)
      request_line = client.gets("\n", MAX_LINE)
      MAX_HEADERS.times do
        line = client.gets("\n", MAX_LINE)
        break if line.nil? || line.strip.empty?
      end
      request_line
    end

    def respond(route)
      case route.first
      when :start then ["200 OK", html_page(*start_one(route.last))]
      when :start_all then ["200 OK", html_page(start_all, nil)]
      when :forbidden then ["403 Forbidden", html_page("Missing or wrong token. Use the links in queue.md.", nil)]
      when :not_found then ["404 Not Found", html_page("Unknown path.", nil)]
      else ["400 Bad Request", html_page("Bad request.", nil)]
      end
    end

    def start_outcome(entry)
      entry["state"] == "reviewing" ? "review tab opened" : "waiting for a free slot"
    end

    def html_page(message, url)
      link = url ? %(<p><a href="#{ERB::Util.html_escape(url)}">Open the PR</a></p>) : ""
      "<!doctype html><title>Review desk</title><p>#{ERB::Util.html_escape(message)}</p>#{link}\n"
    end

    def listener(state)
      info = state["listener"]
      return unless info && info["pid"]

      Process.kill(0, info["pid"])
      info
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def start_url(info, path)
      "http://127.0.0.1:#{info["port"]}#{path}?t=#{info["token"]}"
    end

    # --- Dashboard ---

    def render(state, now)
      entries = visible_entries(state, now)
      groups = [
        ["Verdict ready", "verdict-ready", :verdict],
        ["Reviewing", "reviewing", :verdict],
        ["Starting", "start-requested", :start],
        ["Queued", "queued", :start],
        ["No checkout", "no-checkout", :none],
      ]
      @listener_info = listener(state)
      updated = now.getlocal.strftime("%a %b %-d %H:%M")
      start_all = " · [start all](#{start_url(@listener_info, "/start-all")})" if @listener_info
      lines = ["# Review desk", "", "_Updated #{updated}_ · #{summary_line(entries)}#{start_all}", "",
               filter_line(state, now), "", *legend_lines, ""]
      groups.each do |title, group_state, extra|
        rows = sort_rows(entries.select { |e| e["state"] == group_state })
        lines.concat(render_table(title, rows, extra, now))
      end
      recent = entries.select { |e| DONE_STATES.include?(e["state"]) && recent?(e, now) }
      lines.concat(render_table("Recently filed, taken, or dropped", recent, :outcome, now))
      unless @listener_info
        lines << "Start one: `ruby #{SCRIPT_PATH} start <repo>#<n>` · all queued: `... start --all`"
      end
      atomic_write(QUEUE_PATH, lines.join("\n") + "\n")
    end

    def visible_entries(state, now)
      state["prs"].values.select { |e| Transition.visible?(e, @filters || filters, now) }
    end

    def filter_line(state, now)
      active = @filters || filters
      reasons = state["prs"].values.map { |e| Transition.hidden_reasons(e, active, now) }
      days = active["max_age_days"]
      counts = []
      counts << "#{reasons.count { |r| r.include?(:bot) }} bot PRs" unless active["show_bots"]
      counts << "#{reasons.count { |r| r.include?(:age) }} older than #{days}d" if days
      overlap = "; a PR matching both counts once" if counts.size > 1
      hidden = counts.empty? ? "none" : "#{reasons.count(&:any?)} (#{counts.join(" · ")}#{overlap})"

      show = []
      show << "bots on" unless active["show_bots"]
      show << "max-age off" if days
      toggles = []
      toggles << "show: #{command_list(show)}" if show.any?
      toggles << "hide: #{command_list(["bots off"])}" if active["show_bots"]
      "Hidden: #{hidden} — #{toggles.join(" · ")}"
    end

    def legend_lines
      LEGEND.values.map { |label, meaning| "- **#{label}** — #{meaning}" }
    end

    def command_list(args)
      args.map { |a| "`review-desk.rb #{a}`" }.join(" · ")
    end

    def summary_line(entries)
      queued = entries.select { |e| %w[queued start-requested].include?(e["state"]) }
      teams = queued.flat_map { |e| e["direct"] ? [] : e["teams"] }.tally.sort_by { |t, n| [-n, t] }
      team_text = teams.map { |t, n| "#{t} #{n}" }.join(", ")
      "**#{queued.size} queued** (#{queued.count { |e| e["direct"] }} direct#{", #{team_text}" unless teams.empty?})"
    end

    def sort_rows(rows)
      rows.sort_by { |e| e["created_at"].to_s }.reverse
    end

    def render_table(title, rows, extra, now)
      return [] if rows.empty?

      header = { verdict: "Verdict", start: "Start", outcome: "Outcome", none: "Checkout" }.fetch(extra)
      lines = ["## #{title} (#{rows.size})", "", "| PR | Title | Author | Base | Requested | Age | #{header} |",
               "|----|-------|--------|------|-----------|-----|------|"]
      rows.each do |e|
        cells = [
          "[#{short_ref(e)}](#{e["url"]})", cell(truncate(e["title"].to_s, 70)), e["author"].to_s,
          base_cell(e), request_cell(e), age(e["created_at"], now), extra_cell(e, extra),
        ]
        lines << "| #{cells.join(" | ")} |"
      end
      lines << ""
    end

    def extra_cell(entry, extra)
      case extra
      when :verdict then verdict_cell(entry)
      when :start
        stale = " · [stale verdict](file://#{entry["stale_verdict"]})" if entry["stale_verdict"]
        "#{start_cell(entry)}#{stale}"
      when :outcome then outcome_cell(entry)
      when :none then "no `#{checkout_dir(entry["repo"]).sub(Dir.home, "~")}`"
      end
    end

    def start_cell(entry)
      return "waiting for a slot" if entry["state"] == "start-requested"

      failed = " · last try failed (#{cell(entry["last_error"])})" if entry["last_error"]
      return "`review-desk.rb start #{short_ref(entry)}`#{failed}" unless @listener_info

      "[start](#{start_url(@listener_info, "/start/#{entry["repo"]}/#{entry["number"]}")})#{failed}"
    end

    def verdict_cell(entry)
      parts = []
      path = verdict_path(entry)
      parts << "[#{verdict_label(entry) || "verdict"}](file://#{path})" if File.exist?(path)
      parts << "[stale](file://#{entry["stale_verdict"]})" if entry["stale_verdict"]
      parts.empty? ? "—" : parts.join(" · ")
    end

    def outcome_cell(entry)
      case entry["state"]
      when "taken" then "taken by #{entry["taken_by"]}"
      when "filed" then "filed"
      else "dropped"
      end
    end

    def request_cell(entry)
      parts = []
      parts << "**direct**" if entry["direct"]
      parts.concat(entry["teams"].to_a)
      parts.empty? ? "?" : parts.join(", ")
    end

    def base_cell(entry)
      base = entry["base"].to_s
      base == entry["default_branch"] ? "`#{base}`" : "**`#{base}`** (stacked)"
    end

    def short_ref(entry)
      "#{entry["repo"].split("/").last}##{entry["number"]}"
    end

    def cell(text)
      text.gsub("|", "\\|")
    end

    def truncate(str, max)
      str.length > max ? "#{str[0...max]}…" : str
    end

    def age(timestamp, now)
      return "?" unless timestamp

      seconds = now - Time.parse(timestamp)
      if seconds < 3600 then "#{(seconds / 60).to_i}m"
      elsif seconds < 86_400 then "#{(seconds / 3600).to_i}h"
      elsif seconds < 14 * 86_400 then "#{(seconds / 86_400).to_i}d"
      else "#{(seconds / (7 * 86_400)).to_i}w"
      end
    end

    def recent?(entry, now)
      entry["state_changed_at"] && now - Time.parse(entry["state_changed_at"]) < RETENTION_SECONDS
    end

    # --- Persistence ---

    def checkout_dir(repo)
      File.join(CHECKOUT_ROOT, repo.split("/").last)
    end

    # Watch and start both rewrite state.json, so serialize them on a lock file.
    # The mutex serializes the watch loop and listener thread; flock covers other processes.
    def locked
      FileUtils.mkdir_p(STATE_DIR)
      @lock_mutex.synchronize do
        File.open(LOCK_PATH, File::RDWR | File::CREAT) do |lock|
          lock.flock(File::LOCK_EX)
          state = load_state
          state["workspace_ref"] = @workspace_override if @workspace_override
          result = yield state
          save_state(state) unless dry_run
          result
        end
      end
    end

    def load_state
      return { "prs" => {} } unless File.exist?(STATE_PATH)

      JSON.parse(File.read(STATE_PATH)).tap { |s| s["prs"] ||= {} }
    end

    def filters
      DEFAULT_FILTERS.merge(load_config.slice(*DEFAULT_FILTERS.keys))
    end

    def load_config
      File.exist?(CONFIG_PATH) ? JSON.parse(File.read(CONFIG_PATH)) : {}
    rescue JSON::ParserError
      warn "Ignoring unreadable #{CONFIG_PATH}."
      {}
    end

    def update_filters(changes)
      return if dry_run

      atomic_write(CONFIG_PATH, JSON.pretty_generate(load_config.merge(changes)) + "\n")
    end

    def save_state(state)
      atomic_write(STATE_PATH, JSON.pretty_generate(state) + "\n")
    end

    def atomic_write(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      tmp = "#{path}.tmp-#{Process.pid}"
      File.write(tmp, content)
      File.rename(tmp, path)
    end

    def sh_quote(str)
      "'#{str.gsub("'", %q('\\''))}'"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = { interval: 300, max_concurrent: 3, teams: [], username: "rwc9u" }
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} <watch|tick|start|prepare|prune|bots|max-age> [options]"
    opts.on("--interval SECONDS", Integer, "Seconds between watch ticks (default: 300)") do |v|
      options[:interval] = v
    end
    opts.on("--max-concurrent N", Integer, "Review sessions running at once (default: 3)") do |v|
      options[:max_concurrent] = v
    end
    opts.on("--team SLUG", "Only count requests from this team (repeatable; default: all)") do |v|
      options[:teams] << v
    end
    opts.on("--workspace REF", "cmux workspace for review tabs (default: recorded by watch)") do |v|
      options[:workspace] = v
    end
    opts.on("--port PORT", Integer, "watch: local port for dashboard start links (default: 47321)") do |v|
      options[:port] = v
    end
    opts.on("--username USERNAME", "GitHub username (default: rwc9u)") { |v| options[:username] = v }
    opts.on("--dry-run", "Fetch and render only: no spawning, no cmux, state.json untouched") do
      options[:dry_run] = true
    end
    opts.on("--all", "start: every queued PR") { options[:all] = true }
    opts.on("--yes", "prune: actually remove the worktrees") { options[:yes] = true }
    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end
  parser.parse!
  command = ARGV.shift

  desk = ReviewDesk::Desk.new(
    username: options[:username],
    max_concurrent: options[:max_concurrent],
    teams_filter: options[:teams],
    dry_run: options[:dry_run] || false,
    workspace: options[:workspace],
  )

  case command
  when "watch" then desk.watch(options[:interval], port: options[:port] || ReviewDesk::DEFAULT_PORT)
  when "tick" then desk.tick
  when "start"
    abort "start needs a PR reference or --all" if ARGV.empty? && !options[:all]
    desk.start(ARGV, all: options[:all] || false)
  when "prepare"
    abort "prepare needs an owner/repo#n key" if ARGV.empty?
    exit(desk.prepare(ARGV.first) ? 0 : 1)
  when "prune" then desk.prune(yes: options[:yes] || false)
  when "bots" then desk.bots(ARGV.first)
  when "max-age"
    begin
      desk.max_age(ARGV.first)
    rescue ArgumentError => e
      abort e.message
    end
  else
    abort parser.banner
  end
end
