#!/usr/bin/env ruby
# frozen_string_literal: true

#
# team-pr-stats.rb — Track merged PRs per team member across GitHub org repos
#
# Usage:
#   ruby team-pr-stats.rb --org Kajabi --team "user1:Name One,user2:Name Two"
#   ruby team-pr-stats.rb --org Kajabi --team "rwc9u:Rob Christie,prsimp:Paul Simpson" --months 6
#   ruby team-pr-stats.rb --org Kajabi --team "rwc9u:Rob Christie" --repo kajabi-products
#   ruby team-pr-stats.rb --org Kajabi --team "rwc9u:Rob Christie" --csv
#
# Requires: gh (GitHub CLI) authenticated with access to the target org

require "json"
require "open3"
require "date"
require "optparse"

class TeamPrStats
  attr_reader :org, :teammates, :months, :repo, :csv_mode

  def initialize(org:, teammates:, months: 3, repo: nil, csv_mode: false)
    @org = org
    @teammates = teammates # { "username" => "Display Name" }
    @months = months
    @repo = repo
    @csv_mode = csv_mode
  end

  def run
    verify_gh_cli!
    month_ranges = build_month_ranges
    data = fetch_all(month_ranges)
    render(data, month_ranges)
  end

  private

  def verify_gh_cli!
    _, status = Open3.capture2("gh", "auth", "status")
    return if status.success?

    warn "Error: gh CLI is not authenticated. Run 'gh auth login' first."
    exit 1
  end

  def scope_query
    if repo
      "repo:#{org}/#{repo}"
    else
      "org:#{org}"
    end
  end

  def scope_label
    repo ? repo : "all #{org} repos"
  end

  def build_month_ranges
    today = Date.today
    (0...months).map do |i|
      d = today << i # subtract i months
      first = Date.new(d.year, d.month, 1)
      last = (first >> 1) - 1 # last day of month
      label = first.strftime("%Y-%m")
      {
        label: label,
        start: "#{first}T00:00:00Z",
        end_date: "#{last}T23:59:59Z"
      }
    end.reverse
  end

  def fetch_count(username, month_range)
    query = "#{scope_query} is:pr is:merged merged:#{month_range[:start]}..#{month_range[:end_date]} author:#{username}"
    output, status = Open3.capture2(
      "gh", "api", "-X", "GET", "search/issues",
      "-f", "q=#{query}",
      "--jq", ".total_count"
    )

    unless status.success?
      warn "  Warning: failed to fetch data for #{username} (#{month_range[:label]})"
      return 0
    end

    output.strip.to_i
  end

  def fetch_all(month_ranges)
    data = {}

    teammates.each do |username, name|
      data[username] = { name: name, counts: [], total: 0 }

      month_ranges.each do |mr|
        count = fetch_count(username, mr)
        data[username][:counts] << count
        data[username][:total] += count
        warn "  #{name} (#{mr[:label]}): #{count}"
      end
    end

    data
  end

  def render(data, month_ranges)
    labels = month_ranges.map { |mr| mr[:label] }
    sep = csv_mode ? "," : "|"

    sorted = data.sort_by { |_, v| -v[:total] }

    unless csv_mode
      puts ""
      puts "Merged PRs by Developer"
      puts "Scope: #{scope_label} | Period: #{labels.first} to #{labels.last}"
      puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M')}"
      puts ""
    end

    # Header
    header = ["Developer", "Username", *labels, "Total", "Avg/Mo"].join(sep)
    puts header

    unless csv_mode
      divider = (["---"] * (labels.size + 4)).join(sep)
      puts divider
    end

    # Rows
    sorted.each do |username, info|
      avg = (info[:total].to_f / labels.size).round(1)
      row = [info[:name], username, *info[:counts], info[:total], avg].join(sep)
      puts row
    end

    # Team totals
    unless csv_mode
      month_totals = labels.each_index.map do |i|
        data.values.sum { |v| v[:counts][i] }
      end
      grand_total = month_totals.sum
      team_avg = (grand_total.to_f / labels.size).round(1)
      team_row = ["**TEAM TOTAL**", "", *month_totals, grand_total, team_avg].join(sep)
      puts team_row
    end
  end
end

# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────

if __FILE__ == $PROGRAM_NAME
  options = { months: 3, csv: false }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} --org ORG --team 'user1:Name,user2:Name' [options]"

    opts.on("--org ORG", "GitHub organization (required)") do |v|
      options[:org] = v
    end

    opts.on("--team TEAM", "Comma-separated user:name pairs (required)") do |v|
      options[:team] = v
    end

    opts.on("--months N", Integer, "Number of months to look back (default: 3)") do |v|
      options[:months] = v
    end

    opts.on("--repo REPO", "Specific repo name (default: all org repos)") do |v|
      options[:repo] = v
    end

    opts.on("--csv", "Output as CSV") do
      options[:csv] = true
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!

  unless options[:org] && options[:team]
    warn "Error: --org and --team are required. Run with --help for usage."
    exit 1
  end

  # Parse team: "rwc9u:Rob Christie,prsimp:Paul Simpson"
  teammates = {}
  options[:team].split(",").each do |pair|
    username, name = pair.strip.split(":", 2)
    if username.nil? || name.nil?
      warn "Error: invalid team format '#{pair}'. Expected 'username:Display Name'"
      exit 1
    end
    teammates[username.strip] = name.strip
  end

  warn "Fetching merged PRs for #{teammates.size} team members..."
  warn "Scope: #{options[:repo] || "all #{options[:org]} repos"} | Months: #{options[:months]}"
  warn ""

  stats = TeamPrStats.new(
    org: options[:org],
    teammates: teammates,
    months: options[:months],
    repo: options[:repo],
    csv_mode: options[:csv]
  )

  stats.run
end
