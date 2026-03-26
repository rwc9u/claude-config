#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

DANGEROUS_PATTERNS = [
  /\bDROP\b/i,
  /\bTRUNCATE\b/i,
  /\bDELETE\b/i,
  /\bUPDATE\b(?!.*\bWHERE\b)/im,
  /\bALTER\b.*\bDROP\b/im,
  /\bpg_terminate_backend\b/i
].freeze

PATTERN_DESCRIPTIONS = {
  /\bDROP\b/i => "DROP",
  /\bTRUNCATE\b/i => "TRUNCATE",
  /\bDELETE\b/i => "DELETE",
  /\bUPDATE\b(?!.*\bWHERE\b)/im => "UPDATE without WHERE",
  /\bALTER\b.*\bDROP\b/im => "ALTER ... DROP",
  /\bpg_terminate_backend\b/i => "pg_terminate_backend"
}.freeze

# Read hook input from stdin
begin
  input_data = JSON.parse($stdin.read)
rescue JSON::ParserError => e
  $stderr.puts "Error: Invalid JSON input: #{e.message}"
  exit 1
end

command = input_data.dig("tool_input", "command").to_s

# Allow non-psql commands
exit 0 unless command.match?(/\bpsql\b/)

# Check which dangerous patterns match
matched = PATTERN_DESCRIPTIONS.select { |pattern, _| command.match?(pattern) }

exit 0 if matched.empty?

matched_names = matched.values.join(", ")

output = {
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: [
      "PSQL GUARD: Destructive operation detected (#{matched_names}).",
      "",
      "Command: #{command}",
      "",
      "Please review and approve or deny."
    ].join("\n")
  }
}

puts JSON.generate(output)
exit 0
