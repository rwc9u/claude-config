#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "optparse"
require "yaml"

SOURCES = File.expand_path("../sources.yml", __dir__)

options = { date: Date.today, fetch: nil, section: nil }
OptionParser.new do |opts|
  opts.banner = "Usage: list_sources.rb [--date YYYY-MM-DD] [--section NAME] [--fetch ok|partial|blocked]"
  opts.on("--date DATE", "Date to fill into URL templates (default: today)") { |v| options[:date] = Date.parse(v) }
  opts.on("--section NAME", "Only this section of sources.yml") { |v| options[:section] = v }
  opts.on("--fetch STATUS", "Only sources with this fetch status") { |v| options[:fetch] = v }
end.parse!

sections = YAML.load_file(SOURCES)
sections = sections.slice(options[:section]) if options[:section]
abort "No such section. Available: #{YAML.load_file(SOURCES).keys.join(', ')}" if sections.empty?

sections.each do |section, entries|
  entries = entries.select { |entry| entry.is_a?(Hash) && entry["fetch"] == options[:fetch] } if options[:fetch]
  next if entries.empty?

  puts "## #{section}"
  entries.each do |entry|
    next puts(entry) if entry.is_a?(String)


    status = entry["fetch"] ? "[#{entry['fetch']}] " : ""
    area = entry["area"] ? " (#{entry['area']})" : ""
    puts "#{status}#{entry['name']}#{area}: #{options[:date].strftime(entry['url'])}"
    puts "    #{entry['notes']}" if entry["notes"]
  end
  puts
end
