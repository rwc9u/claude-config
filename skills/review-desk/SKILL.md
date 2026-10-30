---
name: review-desk
description: This skill should be used when the user asks to "start my review desk", "review desk", "track my reviews", "review queue", "start review <n>", "start all reviews", "show/hide bot PRs", "only show PRs from the last week", or invokes /review-desk. It runs a cmux "Reviews" workspace that tracks every open PR awaiting the user's review (direct or team requests), shows a live dashboard, and starts a /review-pr session per PR on request.
argument-hint: "[start <repo>#<n> | start --all | bots on|off | max-age <days>|off | tick | prune]"
---

# Review Desk

One cmux workspace named **Reviews** that tracks every open, non-draft PR where
review is requested from `rwc9u` directly or from one of his teams. A watcher
refreshes a markdown dashboard every 5 minutes. Reviews never start on their
own: the user picks which PRs to start, and each one opens a tab running
`/review-pr <n> low` inside a `wt` worktree of that PR.

```bash
DESK="ruby ${SKILL_DIR}/scripts/review-desk.rb"
```

## Start the desk

1. Look for an existing workspace titled `Reviews`:
   `CMUX_QUIET=1 cmux list-workspaces --json` (match `.workspaces[].title`).
2. Make sure the dashboard file exists so the panel has something to open:
   `mkdir -p ~/.local/state/review-desk && touch ~/.local/state/review-desk/queue.md`
3. If there is no Reviews workspace, create it with the watcher as its first terminal:
   ```bash
   cmux new-workspace --name Reviews --cwd ~/dev --focus false \
     --command "ruby ${SKILL_DIR}/scripts/review-desk.rb watch"
   ```
   It prints `OK workspace:<n>` (this verb ignores `--json`). If the workspace
   exists, start the watcher only when `pgrep -f 'review-desk.rb watch'` finds
   none, with `cmux new-surface --workspace <ref> --command "<same>" --focus false`.
4. Open the dashboard beside it:
   `cmux markdown open ~/.local/state/review-desk/queue.md --workspace <ref> --direction down --focus false`
5. `watch` records the workspace from `CMUX_WORKSPACE_ID`. If
   `~/.local/state/review-desk/state.json` has no `workspace_ref` after the first
   tick, run `$DESK tick --workspace <ref>` once to record it.
6. Report the workspace ref and the first tick's summary. **Never** run
   `select-workspace`, `focus-pane`, or `focus-panel` — the user switches when ready.

`watch` options: `--interval 300`, `--max-concurrent 3`, `--team <slug>`
(repeatable; limits which team requests count — direct requests always count),
`--port 47321` (the start-link listener; `watch` exits if the port is taken).

## Start reviews

When the user says "start review 60090", "start kajabi-products#60090", or
"start all reviews", run:

```bash
$DESK start kajabi-products#60090    # also accepts Kajabi/kajabi-products#60090 or a bare 60090
$DESK start --all                    # every queued PR
```

`start` marks the PRs `start-requested` and opens review tabs right away, without
a full refresh. A single-PR start first checks that PR on GitHub and refuses it
if it is closed, merged, or a draft. Up to `--max-concurrent` reviews run at
once; the rest start on later ticks as slots free. Each review opens as a tab named `<repo>#<n>` in the workspace's right
pane. `/review-pr` is never given `--file` — the user files from that tab.

While `watch` runs, the dashboard's **start** and **start all** links do the
same thing. They hit a listener on `127.0.0.1` that only accepts the random
token generated when `watch` started, and they answer in about half a second.
Without a running watcher, the dashboard shows the `start` commands instead.

## States

`queued → start-requested → reviewing → verdict-ready → filed`, plus:

- `no-checkout` — no `~/dev/<repo>` clone, so no worktree can be made
- `taken` — the team request cleared because a teammate reviewed (shows who)
- `dropped` — closed, merged, draft again, or the request was withdrawn

A new head SHA on a `verdict-ready` or `filed` PR that is still requested sends
it back to `queued`; the old verdict is kept as a stale link. The watcher
notifies once per tick when PRs arrive, and notifies + flashes the tab when a
verdict lands.

## Filters

Two filters hide rows in queued, start-requested, and no-checkout. Rows that are
reviewing, verdict-ready, or recently finished always show. Hidden PRs are still
tracked, so turning a filter off restores them at once. They are left out of the
dashboard, the counts, the sidebar status, arrival notifications, and
`start --all`, but `start <repo>#<n>` still starts one. Settings live in
`~/.local/state/review-desk/config.json`; the watcher re-reads them every tick,
and each change runs a tick right away.

| User says | Run |
|-----------|-----|
| "show bot PRs" | `$DESK bots on` |
| "hide bot PRs" (default) | `$DESK bots off` |
| "only show PRs from the last week" | `$DESK max-age 7` (`7d` also works) |
| "show all ages" (default) | `$DESK max-age off` |

`$DESK bots status` and `$DESK max-age status` report the current setting. Age
is the PR's creation date, as in the dashboard's Age column. Bot PRs are those
whose author is a GitHub Bot account, or whose login ends in `[bot]` or starts
with `app/`.

## Other commands

- `$DESK tick` — one pass. Add `--dry-run` to fetch and render `queue.md`
  without spawning, cmux calls, or saving state.
- `$DESK prune` — print `wt remove` commands for worktrees of filed, taken, and
  dropped PRs. Run them only with `--yes`, and only when the user asks.

## Files

- `~/.local/state/review-desk/state.json` — per-PR state, keyed `owner/repo#n`
- `~/.local/state/review-desk/queue.md` — the dashboard (live-reloads in cmux)
- `~/.local/state/review-desk/verdicts/<owner>-<repo>-<n>.md` — written by
  `/review-pr` when `REVIEW_DESK_DIR` is set; its arrival flips the PR to `verdict-ready`

## Requirements

- Ruby (standard library only), `gh` authenticated with `read:org` for team
  lookups, `wt` (worktrunk), and cmux for the workspace (the script skips cmux
  calls when `CMUX_SOCKET_PATH` is unset).
