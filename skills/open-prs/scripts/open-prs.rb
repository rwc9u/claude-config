#!/usr/bin/env ruby
# frozen_string_literal: true

#
# open-prs.rb — Show open PRs categorized by age into three buckets
#
# Usage:
#   ruby open-prs.rb
#   ruby open-prs.rb --username rwc9u
#
# Requires: gh (GitHub CLI) authenticated

require "json"
require "open3"
require "date"
require "time"
require "optparse"

class OpenPrs
  SEARCH_FIELDS = "number,title,url,repository,createdAt,updatedAt,isDraft,author"

  attr_reader :username, :show_reviewing

  def initialize(username:, show_reviewing: false)
    @username = username
    @show_reviewing = show_reviewing
  end

  def run
    verify_gh_cli!

    warn "Fetching authored PRs..."
    authored = fetch_authored_prs

    reviewing = []
    if show_reviewing
      warn "Fetching PRs to review (requested)..."
      requested = fetch_review_requested_prs

      warn "Fetching PRs to review (already reviewed)..."
      reviewed = fetch_reviewed_prs

      reviewing = merge_reviewing_prs(requested, reviewed)
    end

    all_prs = authored + reviewing
    unless all_prs.empty?
      warn "Fetching review status..."
      enrich_review_decisions!(all_prs)
    end

    render_section("My Open PRs", authored, include_author: false)
    if show_reviewing
      render_section("PRs I'm Reviewing", reviewing, include_author: true)
    end
    render_totals(authored, reviewing)
  end

  private

  def verify_gh_cli!
    _, status = Open3.capture2("gh", "auth", "status")
    return if status.success?

    warn "Error: gh CLI is not authenticated. Run 'gh auth login' first."
    exit 1
  end

  def fetch_authored_prs
    output, status = Open3.capture2(
      "gh", "search", "prs",
      "--author=#{username}",
      "--state=open",
      "--archived=false",
      "--limit", "100",
      "--json", SEARCH_FIELDS,
    )

    unless status.success?
      warn "Error fetching authored PRs"
      return []
    end

    JSON.parse(output)
  end

  def fetch_review_requested_prs
    output, status = Open3.capture2(
      "gh", "search", "prs",
      "--review-requested=#{username}",
      "--state=open",
      "--archived=false",
      "--limit", "100",
      "--json", SEARCH_FIELDS,
    )

    return [] unless status.success?

    JSON.parse(output)
  end

  def fetch_reviewed_prs
    output, status = Open3.capture2(
      "gh", "search", "prs",
      "--reviewed-by=#{username}",
      "--state=open",
      "--archived=false",
      "--limit", "100",
      "--json", SEARCH_FIELDS,
    )

    return [] unless status.success?

    JSON.parse(output)
  end

  def merge_reviewing_prs(requested, reviewed)
    combined = requested + reviewed
    combined
      .uniq { |pr| pr["url"] }
      .reject { |pr| pr.dig("author", "login")&.downcase == username.downcase }
  end

  # Batch-fetch reviewDecision via GraphQL for all PRs
  def enrich_review_decisions!(prs)
    # Group PRs by owner/repo for efficient querying
    by_repo = prs.group_by { |pr| pr.dig("repository", "nameWithOwner") }

    by_repo.each do |repo_full, repo_prs|
      owner, name = repo_full.split("/", 2)
      next unless owner && name

      # Build a single GraphQL query for all PRs in this repo
      fragments = repo_prs.each_with_index.map do |pr, i|
        "pr#{i}: pullRequest(number: #{pr["number"]}) { number reviewDecision headRefName }"
      end

      query = "query { repository(owner: \"#{owner}\", name: \"#{name}\") { #{fragments.join(" ")} } }"

      output, status = Open3.capture2(
        "gh", "api", "graphql",
        "-f", "query=#{query}",
        "--jq", ".data.repository",
      )

      next unless status.success?

      begin
        data = JSON.parse(output)
        repo_prs.each_with_index do |pr, i|
          decision = data.dig("pr#{i}", "reviewDecision")
          branch = data.dig("pr#{i}", "headRefName")
          pr["reviewDecision"] = decision if decision
          pr["headRefName"] = branch if branch
        end
      rescue JSON::ParserError
        # Skip enrichment for this repo on parse failure
      end
    end
  end

  def categorize(prs)
    now = Time.now
    one_week_ago = now - (7 * 86_400)
    eight_weeks_ago = now - (56 * 86_400)

    buckets = { recent: [], mid: [], old: [] }

    prs.each do |pr|
      updated = Time.parse(pr["updatedAt"])
      created = Time.parse(pr["createdAt"])

      if updated >= one_week_ago
        buckets[:recent] << pr
      elsif created >= eight_weeks_ago
        buckets[:mid] << pr
      else
        buckets[:old] << pr
      end
    end

    buckets.each_value { |list| list.sort_by! { |pr| pr["updatedAt"] }.reverse! }
    buckets
  end

  def render_section(title, prs, include_author:)
    puts ""
    puts "## #{title}"

    if prs.empty?
      puts ""
      puts "_None_"
      return
    end

    buckets = categorize(prs)

    render_table("Active This Week", buckets[:recent], include_author: include_author)
    render_table("1\u20138 Weeks", buckets[:mid], include_author: include_author)
    render_table("Older", buckets[:old], include_author: include_author)
  end

  def render_table(label, prs, include_author:)
    puts ""
    puts "### #{label} (#{prs.size})"

    if prs.empty?
      puts ""
      puts "_None_"
      return
    end

    puts ""
    if include_author
      puts "| Repo | PR | Title | Branch | Author | Status | Updated |"
      puts "|------|-----|-------|--------|--------|--------|---------|"
    else
      puts "| Repo | PR | Title | Branch | Status | Updated |"
      puts "|------|-----|-------|--------|--------|---------|"
    end

    prs.each do |pr|
      repo = pr.dig("repository", "name") || "?"
      number = pr["number"]
      url = pr["url"]
      title = truncate(pr["title"].to_s, 60)
      branch = pr["headRefName"] || "?"
      status = format_status(pr)
      updated = format_date(pr["updatedAt"])

      if include_author
        author = pr.dig("author", "login") || "?"
        puts "| #{repo} | [##{number}](#{url}) | #{title} | `#{branch}` | @#{author} | #{status} | #{updated} |"
      else
        puts "| #{repo} | [##{number}](#{url}) | #{title} | `#{branch}` | #{status} | #{updated} |"
      end
    end
  end

  def render_totals(authored, reviewing)
    puts ""
    puts "---"
    puts ""
    puts "**Authored:** #{authored.size} open \u00b7 " \
         "**Reviewing:** #{reviewing.size} open \u00b7 " \
         "**Total:** #{authored.size + reviewing.size}"
  end

  def format_status(pr)
    if pr["isDraft"]
      "Draft"
    else
      case pr["reviewDecision"]
      when "APPROVED" then "Approved"
      when "CHANGES_REQUESTED" then "Changes Requested"
      when "REVIEW_REQUIRED" then "Review Required"
      else "Open"
      end
    end
  end

  def format_date(date_str)
    return "?" unless date_str

    date = Date.parse(date_str)
    days_ago = (Date.today - date).to_i

    if days_ago == 0
      "today"
    elsif days_ago == 1
      "yesterday"
    elsif days_ago < 7
      "#{days_ago}d ago"
    else
      date.strftime("%b %-d")
    end
  end

  def truncate(str, max)
    str.length > max ? "#{str[0...max]}\u2026" : str
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [--username USERNAME] [--reviewing]"

    opts.on("--username USERNAME", "GitHub username (default: rwc9u)") do |v|
      options[:username] = v
    end

    opts.on("--reviewing", "Also show PRs you are reviewing") do
      options[:reviewing] = true
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!

  username = options[:username] || "rwc9u"

  warn "Fetching open PRs for #{username}..."
  warn ""

  OpenPrs.new(username: username, show_reviewing: options[:reviewing] || false).run
end
