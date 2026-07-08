#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

PREAMBLE = "> This is a bot response."

# Matches the gh subcommands that post user-visible comments/reviews.
COMMENT_COMMAND_PATTERN = /\bgh\s+(pr\s+comment|issue\s+comment|pr\s+review)\b/

# Body flags. We only enforce when a body is being supplied inline; commands
# like `gh pr review --approve` (no body) are fine.
BODY_FLAG_PATTERN = /(?:^|\s)(?:-b|--body|--body-file)\b/

# Initiating a Cursor review is a command directed at the bot, not a
# human-facing reply, so it is exempt from the preamble requirement.
CURSOR_REVIEW_PATTERN = /@cursor\s+review\b/

begin
  input_data = JSON.parse($stdin.read)
rescue JSON::ParserError => e
  $stderr.puts "Error: Invalid JSON input: #{e.message}"
  exit 1
end

command = input_data.dig("tool_input", "command").to_s

exit 0 unless command.match?(COMMENT_COMMAND_PATTERN)
exit 0 unless command.match?(BODY_FLAG_PATTERN)
exit 0 if command.match?(CURSOR_REVIEW_PATTERN)
exit 0 if command.include?(PREAMBLE)

output = {
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: [
      "GH COMMENT GUARD: GitHub comment/review bodies must start with the preamble line:",
      "",
      "    #{PREAMBLE}",
      "",
      "Retry the command with that line as the first line of the body (before a blank line and the actual message).",
    ].join("\n"),
  },
}

puts JSON.generate(output)
exit 0
