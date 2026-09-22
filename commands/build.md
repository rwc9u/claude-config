---
description: Implement the plan agreed in this conversation, running this turn on Opus
model: opus
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

Implement what was agreed earlier in this conversation. If `$ARGUMENTS` is
given, it narrows or restates the scope; it does not replace the discussion.

You have the full conversation context. Do not redesign, widen, or narrow the
agreed approach. Follow `~/.claude/CLAUDE.md` and the shared rules for the
stack you are in.

1. Restate the scope in two or three lines before touching files.
2. Make the code changes with tests alongside them.
3. Run the specs and linter for the changed files only, and get them green.
4. Report: files changed, what was verified, what was not, and any decision
   you had to make that the discussion did not settle.

Do not commit unless the user asked for that as part of the plan.
