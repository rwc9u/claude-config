---
name: review-pr
description: This skill should be used when the user asks to "review this PR", "review PR <number>", "give me a verdict on this PR", "should I approve this", "act as the reviewer", "review and approve", or wants a reviewer's approve/request-changes recommendation on a pull request they are reviewing (not authoring). Do NOT use when the user wants a raw findings scan (use the built-in code-review skill) or wants to triage existing PR comments (use pr-feedback-triage).
argument-hint: "[pr-number] [low|medium|high|xhigh|max] [--file] [--desk]"
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
  through to the underlying code-review scan. **If omitted, pass `low`
  explicitly** — do not let the scan fall back to its own default (the last
  level the user typed), which makes review time unpredictable. Pass a higher
  level only when the user asks for one.
- `--file` — pre-authorizes filing the finished review on GitHub without a
  second confirmation prompt. Without this flag, always ask before filing.
- `--desk` — the review desk launched this session. Write the verdict file in
  step 5 and run the desk commands in step 6.

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

Invoke the built-in `code-review` skill with the PR number and an effort
level — the one the user gave, or `low` when they gave none — and wait for
its verified findings. Always pass the level; omitting it inherits whatever
level was last used and can make the scan run far longer than a verdict needs.
If a completed scan for the same PR at the same head SHA already exists in
this session, reuse it instead of re-running.

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

### 4. Publish a PR explainer

Publish an Artifact that explains the PR to someone who hasn't opened it, and
reference it from the verdict. Follow the Artifact tool's own flow (quickstart
with intent `other`), and load `artifact-diagramming` for the visual.

- **Why**: the problem the PR solves, in two or three sentences
- **What changed**: grouped by area, each as before → after, naming the key
  files; skip lockfiles and generated files
- **Visual**: one diagram of the real mechanism the PR touches, such as the
  data flow, request sequence, schema change, state machine, or a before/after
  comparison; never a decorative chart
- **Verdict**: the recommendation, blocking items, and risks to watch
- Title `<repo>#<n>: <short topic>`; leave out secrets, tokens, and customer data
- On a re-review, if an earlier verdict file for this PR (including a stale
  `<owner>-<repo>-<number>-<sha>.md`) has an `artifact:` line, read that
  artifact and publish to its URL instead of creating a new one

### 5. Report to the user

Present the verdict first, then the explainer link, then blocking items, then
non-blocking items. Keep it tight — this is for the human reviewer to act on.

With `--desk`, also write the report to
`~/.local/state/review-desk/verdicts/<owner>-<repo>-<number>.md` (create the directory if needed).
Line 1 is `verdict: <Approve|Approve with comments|Request changes>`, line 2 is
`head: <full 40-character head SHA reviewed>`, line 3 is `artifact: <explainer
URL>`, then the report.

### 6. File the review

Only after explicit confirmation (or when `--file` was passed):

- **Approve**: `gh pr review <number> --approve` with no body — never add the
  verdict rationale to an approval
- **Approve with comments**: one approving review whose non-blocking items are
  inline comments on their lines, still with no review body:
  `gh api repos/<owner>/<repo>/pulls/<number>/reviews -f event=APPROVE` plus a
  `comments[]` entry (`path`, `line`, `body`) per item. Start each comment body
  with `> 🤖 Posted by Claude on behalf of Rob.` and a blank line. Use
  `event=COMMENT` instead when approval isn't yours to give
- **Request changes**: `gh pr review <number> --request-changes` with a body
  of the blocking items, starting with `> 🤖 Posted by Claude on behalf of Rob.`
  and a blank line; leave non-blocking items out unless the user wants them
- Never file a review without the user's go-ahead in this session unless
  `--file` was explicitly passed
- With `--desk`, after filing run
  `nohup ~/.claude/skills/review-desk/scripts/review-desk.sh tick >/dev/null 2>&1 &`
  as the last step and say the tab will close; the desk closes it within seconds
- With `--desk`, when the user says to ignore, dismiss, or skip
  the PR instead of filing, don't write an "Ignore" verdict; run
  `nohup ~/.claude/skills/review-desk/scripts/review-desk.sh dismiss <owner/repo#n> >/dev/null 2>&1 &`
  as the last step and say the tab will close
