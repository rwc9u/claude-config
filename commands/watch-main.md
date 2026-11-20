---
description: Check kajabi-products main CI; on a new failure, fix it in a worktree, open a PR and DM Rob. Runs on Opus.
model: opus
---

Check whether `main` in `~/dev/kajabi-products` is green. If something new has
failed, diagnose it, fix it, open a PR and tell Rob. Meant to run on a loop:
`/loop 5m /watch-main`.

This turn runs on Opus, so write the fix here. Do not delegate it to an agent.

## 1. Check main

Run from `~/dev/kajabi-products`. Fetch only: never `git pull` in the main
checkout (that is what `kmu` is for).

```bash
cd ~/dev/kajabi-products && git fetch origin main 2>&1 | tail -1
for sha in $(git log origin/main -8 --format=%H); do
  echo "== $(git log -1 --format='%h %s' $sha)"
  gh api "repos/{owner}/{repo}/commits/$sha/check-runs?per_page=100" \
    --jq '[.check_runs[] | select(.conclusion != "success" and .conclusion != "skipped") | "\(.name)=\(.conclusion // .status)"] | join(", ")'
  gh api "repos/{owner}/{repo}/commits/$sha/status" \
    --jq '"status: \(.state) | " + ([.statuses[] | select(.state != "success") | "\(.context)=\(.state)"] | join(", "))'
done
```

`pending` and `in_progress` are not failures. Only `failure` or `error` is red.

If nothing is red, or every red is already known (section 2), report in one or
two lines and stop.

## 2. Decide whether a red is new

Do this before any other work, so one problem gets one PR and one DM.

- **Already handled in this session**: skip it.
- **An open PR already covers it**: check
  `gh pr list --author @me --state open` and the branch list. Skip it.
- **Recurring scheduled workflows** fail on whatever commit is head, so the
  same red shows up on new commits. Treat these as one issue, not one per
  commit:
  - `smarter_testing_analysis_*`: runs every 2 hours. Confirm the failing step
    matches the known cause before skipping; a different step is a new issue.
  - `cofounder_evals` (nightly): LLM-graded evals. A case that fails its graded
    checks is a real eval result, not a CI bug. Do not change prompts, skills
    or eval criteria. DM Rob once per night with the failed cases and reasons,
    and note any case that also failed the night before.
- **Anything in `build_and_test`** (spec jobs, JS tests, static analysis) on
  `main` is always worth a look.

## 3. Diagnose

Work from evidence, not from the job name.

- Get the workflow from the failed status's `target_url`, then use the
  CircleCI API. `CIRCLECI_TOKEN` is in the environment.
  - Jobs: `GET https://circleci.com/api/v2/workflow/<id>/job`
  - Steps and per-node status:
    `GET https://circleci.com/api/v1.1/project/gh/Kajabi/kajabi-products/<job_number>`
    (each action has an `output_url` with the step log)
  - Failed tests:
    `GET https://circleci.com/api/v2/project/gh/Kajabi/kajabi-products/<job_number>/tests`
- Check the workflow's recent history
  (`/api/v2/insights/gh/Kajabi/kajabi-products/workflows/<name>?branch=main`)
  to see whether this is new or recurring, and `git log` on the files involved
  to find the change that introduced it.
- Read code from `origin/main` (`git show origin/main:<path>`), since the main
  checkout may be behind.
- In zsh, unquoted variables do not word-split. Pass arguments explicitly.

State the root cause in a sentence before fixing anything. If you cannot, say
what you found and DM Rob instead of guessing at a fix.

### How it got into main

For every new red, also work out why the PR that introduced it merged green.
This goes in the PR description (section 6), so verify it; do not guess.

- Find the introducing PR (`git log` on the files, then `gh pr view <n>`), and
  look at its last pipeline before merge: its labels, the workflow that ran
  (`build_and_test` or `build_and_test_smart_selection`), and whether the
  failing job ran at all.
- For a failing spec, check whether that spec ran on the PR: the job's test
  results (`/tests` endpoint) list every file that ran. Common answers:
  - **Smart selection skipped it**: the spec was not selected for the PR's
    diff. Say which file changed and which spec should have been related.
  - **It ran and passed**: order-dependent or flaky (name the condition), or
    the PR's branch was behind `main` and two PRs that were each green
    conflict once both land. Name both PRs.
  - **CI did not run or was not required**: merged with checks pending,
    skipped, or on a stale run.
  - **Not a PR at all**: a scheduled workflow, an external service, or a
    change outside the repo.
- If the evidence does not settle it, say what you checked and that the cause
  is unconfirmed.

## 4. Fix it in a worktree

- `wt switch -c rc/<feature>NN-<task> --base origin/main --no-cd`. Worktrees
  land in `.claude/worktrees/`. No ticket ID in the branch name.
- Make the smallest change that fixes the cause. Leave deliberate guards and
  unrelated code alone; if the full fix needs a design decision, fix what is
  clear and raise the rest in the DM.
- Never edit `.circleci/config.yml` by hand. Edit `config/circleci/`, then run
  `bin/circleci_config_pack` and `circleci config validate`.
- Add or update specs with the change. No comments in specs. One-line code
  comments, no ticket IDs.

## 5. Verify locally, narrowly

- Run only the failing spec or the spec files you changed. Never a directory
  or the suite.
- First spec run in a new worktree: symlink `tmp/cache/assets` to the main
  checkout's, and `.env.test` if it is missing.
- If bundler is not found, `source ~/.asdf/asdf.sh` and use `asdf exec`.
- Redirect rspec to a log file and tail it. Never pipe rspec through grep.
- Lint only the changed files.
- If the failure cannot be reproduced locally (real API calls, CI-only steps),
  say so. Do not claim it was verified.

## 6. Commit, push, PR

- Conventional commit, two-paragraph body wrapped at 80, with the
  `Co-Authored-By` line.
- `gh pr create --draft --assignee rwc9u --label run-ci`, using the PR
  template without the Checklist. No hard wraps in the body. "No specific
  Linear ticket" plus how it was found.
- In the Description, say how the failure reached `main`: the introducing PR
  and why its CI was green, from "How it got into main" above. One or two
  sentences, stated as fact only where verified.
- Add `run-smart-analysis` when the change touches the Smarter Testing
  analysis job, since `run-ci` does not exercise it.
- Keep open questions out of the PR body. They go in the DM.
- Open it with `gh pr view <n> --web`.

## 7. DM Rob

One Slack DM to Rob (`U01C4K5GQLC`) per new issue:

- what failed and where, with the workflow link;
- the cause, in plain words;
- the PR link, and what was and was not verified;
- any decision that is his to make.

Check every link in the message is real before sending. If you have to correct
a message, reply in the same thread.

## 8. Report

End the turn with a short status: what is red, what is new, what you did, and
what is waiting on Rob. On later ticks, also report when an earlier PR's checks
finish or it merges.
