#!/usr/bin/env ruby
# frozen_string_literal: true

# Summarize every Terraform Cloud plan posted on a PR's head commit, one block per workspace.
#
# Usage: ruby tfc_plans.rb <owner/repo> <pr-number>
# Token: TF_TOKEN_app_terraform_io, else ~/.terraform.d/credentials.tfrc.json

require "json"
require "net/http"
require "open3"
require "uri"

module TfcPlans
  API = "https://app.terraform.io/api/v2"
  CONTEXT_PREFIX = "Terraform Cloud/"
  RUN_ID = %r{/runs/(run-\w+)}
  MAX_VALUE = 80

  module_function

  def token
    ENV["TF_TOKEN_app_terraform_io"] || begin
      path = File.expand_path("~/.terraform.d/credentials.tfrc.json")
      JSON.parse(File.read(path)).dig("credentials", "app.terraform.io", "token")
    rescue Errno::ENOENT, JSON::ParserError
      nil
    end
  end

  def gh(*args)
    out, err, status = Open3.capture3("gh", *args)
    abort "gh #{args.first(2).join(" ")} failed: #{err.strip}" unless status.success?
    JSON.parse(out)
  end

  # Returns [status code, parsed body or nil]; follows the archivist redirect for plan JSON.
  def tfc_get(url, limit = 3)
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@token}" if uri.host == "app.terraform.io"
    req["Content-Type"] = "application/vnd.api+json"
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    return tfc_get(res["location"], limit - 1) if res.is_a?(Net::HTTPRedirection) && limit.positive?

    [res.code.to_i, res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body) : nil]
  end

  def short(value)
    text = value.is_a?(String) ? value : JSON.generate(value)
    text.length > MAX_VALUE ? "#{text[0, MAX_VALUE]}…" : text
  end

  # Only top-level keys, and never one Terraform flags as sensitive: values end up in verdict files.
  def changed_attributes(change)
    before = change["before"] || {}
    after = change["after"] || {}
    return [] unless before.is_a?(Hash) && after.is_a?(Hash)

    (before.keys | after.keys).sort.filter_map do |key|
      next if before[key] == after[key]

      sensitive = change.dig("before_sensitive", key) || change.dig("after_sensitive", key)
      unknown = change.dig("after_unknown", key)
      next "#{key}: (sensitive)" if sensitive

      after_text = unknown == true ? "(known after apply)" : short(after[key])
      "#{key}: #{short(before[key])} → #{after_text}"
    end
  end

  def change_lines(plan)
    plan["resource_changes"].to_a.reject { |rc| rc.dig("change", "actions") == ["no-op"] }.map do |rc|
      actions = rc.dig("change", "actions").join(",")
      replace = rc.dig("change", "replace_paths")
      line = "  #{actions} #{rc["address"]}"
      line += " (replaced because: #{replace.map { |p| p.join(".") }.join(", ")})" if replace
      attrs = actions == "update" ? changed_attributes(rc["change"]) : []
      [line, *attrs.map { |a| "      #{a}" }]
    end.flatten
  end

  # Speculative plans run on the merge commit, so main's commits since this apply show up too.
  def last_apply(workspace_id)
    query = "filter%5Bstatus%5D=applied&page%5Bsize%5D=1&include=configuration_version.ingress_attributes"
    _, runs = tfc_get("#{API}/workspaces/#{workspace_id}/runs?#{query}") if workspace_id
    applied = runs&.dig("data", 0) or return "last apply: unknown"

    sha = runs["included"].to_a.find { |i| i["type"] == "ingress-attributes" }&.dig("attributes", "commit-sha")
    "last apply: #{sha || "unknown commit"} at #{applied.dig("attributes", "created-at")}"
  end

  def workspace_block(status, head_sha)
    lines = ["## #{status["context"].delete_prefix(CONTEXT_PREFIX)}",
             "check: #{status["state"]} — #{status["description"]}",
             "run: #{status["target_url"]}",]
    run_id = status["target_url"].to_s[RUN_ID, 1]
    return lines << "!! no run id in the check URL" unless run_id

    code, run = tfc_get("#{API}/runs/#{run_id}?include=plan")
    return lines << "!! could not read the run (HTTP #{code})" unless run

    lines << "run status: #{run.dig("data", "attributes", "status")}"
    cv = run.dig("data", "relationships", "configuration-version", "data", "id")
    _, ingress = tfc_get("#{API}/configuration-versions/#{cv}/ingress-attributes") if cv
    sha = ingress&.dig("data", "attributes", "commit-sha")
    lines << (sha == head_sha ? "commit: #{sha[0, 7]} (PR head)" : "!! STALE: planned #{sha.to_s[0, 7]}, PR head is #{head_sha[0, 7]}")

    lines << last_apply(run.dig("data", "relationships", "workspace", "data", "id"))

    plan = run["included"].to_a.find { |i| i["type"] == "plans" }
    return lines << "!! no plan on this run" unless plan

    attrs = plan["attributes"]
    lines << "plan: #{attrs["status"]}, +#{attrs["resource-additions"]} ~#{attrs["resource-changes"]} " \
             "-#{attrs["resource-destructions"]} import #{attrs["resource-imports"].to_i}"
    return lines << "!! plan has not finished; review it once it does" unless attrs["status"] == "finished"

    code, json = tfc_get("#{API}/plans/#{plan["id"]}/json-output-redacted")
    return lines << "!! could not read the plan JSON (HTTP #{code}); read the run in the UI" unless json

    changes = change_lines(json)
    lines << "changes:" << (changes.empty? ? "  none" : changes)
    drift = json["resource_drift"].to_a.map { |d| "  #{d.dig("change", "actions").join(",")} #{d["address"]}" }
    lines << "drift (changed outside Terraform since the last apply; reverted only if also under changes):" << drift unless drift.empty?
    outputs = json["output_changes"].to_h.reject { |_, c| c["actions"] == ["no-op"] }.keys
    lines << "output changes: #{outputs.join(", ")}" unless outputs.empty?
    lines.flatten
  end

  def run(repo, number)
    @token = token or abort "No Terraform Cloud token: set TF_TOKEN_app_terraform_io or run `terraform login`."
    head_sha = gh("pr", "view", number, "-R", repo, "--json", "headRefOid")["headRefOid"]
    statuses = gh("api", "repos/#{repo}/commits/#{head_sha}/status")["statuses"]
               .select { |s| s["context"].start_with?(CONTEXT_PREFIX) }
               .sort_by { |s| s["context"] }

    puts "# Terraform Cloud plans for #{repo}##{number} at #{head_sha}", ""
    if statuses.empty?
      puts "No Terraform Cloud checks on the PR head."
      return
    end

    blocks = statuses.map { |status| Thread.new { workspace_block(status, head_sha) } }.map(&:value)
    blocks.each { |block| puts block, "" }
  end
end

if $PROGRAM_NAME == __FILE__
  abort "usage: tfc_plans.rb <owner/repo> <pr-number>" unless ARGV.size == 2
  TfcPlans.run(ARGV[0], ARGV[1])
end
