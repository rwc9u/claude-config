---
name: review-pr
description: This skill should be used when the user asks to "review this PR", "review PR <number>", "give me a verdict on this PR", "should I approve this", "act as the reviewer", "review and approve", or wants a reviewer's approve/request-changes recommendation on a pull request they are reviewing (not authoring). Do NOT use when the user wants a raw findings scan (use the built-in code-review skill) or wants to triage existing PR comments (use pr-feedback-triage).
argument-hint: "[pr-number] [low|medium|high|xhigh|max] [--file]"
---

# Review Pull Request

Act as the reviewer for a pull request and produce a reviewer's verdict —
Approve, Approve with comments, or Request changes — not a fix-it list for the
author. The user is reviewing someone else's change; never apply fixes to the
working tree.

## Arguments

All arguments are optional and may be combined in any order:

- `<pr-number>` — the PR to review. If omitted, look for an open PR on the
  current branch with `gh pr view` and confirm the target with the user
  before reviewing.
- `<effort-level>` — one of `low`, `medium`, `high`, `xhigh`, `max`; passed
  through to the underlying code-review scan. If omitted, the scan uses its
  own default (the last level the user typed).
- `--file` — pre-authorizes filing the finished review on GitHub without a
  second confirmation prompt. Without this flag, always ask before filing.

## Process

### 1. Gather context

Run in parallel:

- `gh pr view <number>` for the description, author, state, and base branch
- `gh pr view <number> --comments` for existing review activity

Skip the deep review and say so if the PR is closed, merged, or the user
already filed a review on it. If the PR is stacked (base branch is not the
default branch), note it — the verdict should mention that base PRs need
review first.

### 2. Run the findings scan

Invoke the built-in `code-review` skill with the PR number (and effort level
if one was given) and wait for its verified findings. If a completed scan for
the same PR at the same head SHA already exists in this session, reuse it
instead of re-running.

### 3. Render a verdict

Weigh each finding as a reviewer, not an author:

- **Blocking**: correctness bugs, data-integrity or security issues,
  user-facing breakage, violations of repo GUARDRAIL rules
- **Non-blocking**: style, minor efficiency, reuse suggestions, nitpicks
- Judge findings against the PR's stated intent — behavior the PR pins with
  specs, explains in its description, or defers to a named follow-up ticket
  is a decision, not a defect
- Conclude with exactly one recommendation: **Approve**, **Approve with
  comments**, or **Request changes**, plus one or two sentences of rationale

### 4. Report to the user

Present the verdict first, then blocking items, then non-blocking items.
Keep it tight — this is for the human reviewer to act on.

### 5. File the review

Only after explicit confirmation (or when `--file` was passed):

- Use `gh pr review <number> --approve` or `--request-changes` (or
  `--comment` for "approve with comments" when approval isn't yours to give)
- Start the body with `> This is a bot response.` followed by a blank line
- Body = the verdict rationale plus blocking items; leave non-blocking items
  out unless the user wants them included
- Never file a review without the user's go-ahead in this session unless
  `--file` was explicitly passed
