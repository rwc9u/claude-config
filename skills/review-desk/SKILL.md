---
name: review-desk
description: This skill should be used when the user asks to "start my review desk", "review desk", "track my reviews", "review queue", "start review <n>", "review <PR link>", "start all reviews", "show/hide bot PRs", "only show PRs from the last week", "dismiss <PR>", "ignore <PR>", "undismiss <PR>", or invokes /review-desk. It runs a cmux "Reviews" workspace that tracks every open PR awaiting the user's review (direct or team requests), shows a live dashboard, and starts a /review-pr session per PR on request.
argument-hint: "[start [--again] <repo>#<n> | start <PR URL> | start --all | dismiss|undismiss <repo>#<n> | bots on|off | max-age <days>|off | tick | prune]"
---

# Review Desk

One cmux workspace named **Reviews** that tracks every open, non-draft PR where
review is requested from `rwc9u` directly or from one of his teams. A watcher
refreshes a markdown dashboard every 5 minutes. Reviews never start on their
own: the user picks which PRs to start, and each one opens a tab running
`/review-pr <n> low --desk` inside a `wt` worktree of that PR. A PR requested only from
`db-migration-reviewers` gets `/review-migration-pr <n> --desk` instead. Review tabs run
`claude --model opus`, whatever the default model is.

```bash
DESK="${SKILL_DIR}/scripts/review-desk.sh"
```

## Start the desk

1. Look for an existing workspace titled `Reviews`:
   `CMUX_QUIET=1 cmux list-workspaces --json` (match `.workspaces[].title`).
2. Make sure the dashboard file exists so the panel has something to open:
   `mkdir -p ~/.local/state/review-desk && touch ~/.local/state/review-desk/queue.md`
3. If there is no Reviews workspace, create it with the watcher as its first terminal:
   ```bash
   cmux new-workspace --name Reviews --cwd ~/dev --focus false \
     --command "${SKILL_DIR}/scripts/review-desk.sh watch"
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
$DESK start https://github.com/Kajabi/kajabi-products/pull/60090   # any open PR, requested or not
$DESK start --all                    # every queued PR
```

A PR URL works for any open, non-draft PR, even one nobody requested from you
or one already taken or dropped (filed too, once it has new commits or replies).
`$DESK start --again <ref>` reopens a PR you already reviewed as a follow-up even
when nobody has replied. It becomes a manual entry (Requested
shows `you (manual)`) that behaves like a direct request and ignores `max-age`.

`start` marks the PRs `start-requested` and opens review tabs right away, without
a full refresh. A single-PR start first checks that PR on GitHub and refuses it
if it is closed, merged, or a draft. Up to `--max-concurrent` reviews run at
once; the rest start on later ticks as slots free. Each review opens as a tab named `<repo>#<n>` in the workspace's right
pane. `/review-pr` is never given `--file` — the user files from that tab.

While `watch` runs, the dashboard's **start** and **start all** links do the
same thing. They hit a listener on `127.0.0.1` that only accepts the random
token generated when `watch` started, and they answer in about half a second.
Without a running watcher, the dashboard shows the `start` commands instead.

## Dismiss reviews

When the user says "dismiss 60487", "ignore kajabi-products#60487", or
"undismiss 60487", run:

```bash
$DESK dismiss kajabi-products#60487     # same reference forms as start
$DESK undismiss kajabi-products#60487
```

`dismiss` works on any tracked PR that isn't already finished. It moves the PR
to `dismissed`, updates the dashboard, and closes its review tab. `undismiss`
puts it back in `queued`; the next tick rechecks it on GitHub. While `watch`
runs, queued, starting, no-checkout, and verdict-ready rows have a **dismiss**
link, and a recently dismissed row has an **undo** link.

## States

`queued → start-requested → reviewing → verdict-ready → filed`, plus:

- `no-checkout` — no `~/dev/<repo>` clone, so no worktree can be made
- `taken` — the team request cleared because a teammate reviewed (shows who)
- `dropped` — closed, merged, draft again, or the request was withdrawn
- `dismissed` — the user skipped it; new pushes and requests leave it there
  until `undismiss`, but closing or merging still drops it

A new head SHA on a `verdict-ready` or `filed` PR that is still requested sends
it back to `queued`; the old verdict is kept as a stale link. For 14 days after
filing, a comment or review from anyone but you or a bot after your latest review
or comment also sends it back, as a **follow-up** (unless you approved the current
head). Follow-ups run `/review-pr <n> low --desk --followup` and return to `filed`
once you reply or review again. A `verdict-ready`
PR whose request is withdrawn becomes `taken` or `dropped`. Worktree creation
is serialized per repo; if it fails, the PR goes back to `queued` with "last try
failed" in its Start cell and can be started again. A `reviewing` PR whose tab
is gone (closed, or cmux quit) before a verdict lands goes back to `queued` the
same way on the next tick. The watcher
notifies once per tick when PRs arrive, and notifies + flashes the tab when a
verdict lands. When a PR reaches `filed` or `dismissed`, the next tick closes its review tab.
Once a finished review's tab is gone, the desk runs `wt remove` on its worktree, once; a
worktree with uncommitted changes fails removal and stays for `prune`.

## Filters

Two filters hide rows in queued, start-requested, and no-checkout. Rows that are
reviewing, verdict-ready, or recently finished always show. Hidden PRs are still
tracked, so turning a filter off restores them at once. They are left out of the
dashboard, the counts, the sidebar status, arrival notifications, and
`start --all`, but `start <repo>#<n>` still starts one. Settings live in
`~/.local/state/review-desk/config.json`; the watcher re-reads them every tick,
and each `bots`/`max-age` command runs a tick right away.

| User says | Run |
|-----------|-----|
| "show bot PRs" | `$DESK bots on` |
| "hide bot PRs" (default) | `$DESK bots off` |
| "only show PRs from the last week" | `$DESK max-age 7` (`7d` also works) |
| "show all ages" (default) | `$DESK max-age off` |

While `watch` runs, the dashboard's filter line has links for the same changes:
**bots** show/hide, **age** 7d/30d/all (the current setting is bold), and
**refresh now**. Filter links only re-render cached state, so they answer about
as fast as start links; **refresh now** runs a full tick and answers once
GitHub has been fetched. Without a running watcher, the line shows commands.

`$DESK bots status` and `$DESK max-age status` report the current setting. Age
is the PR's creation date, as in the dashboard's Age column. Bot PRs are those
whose author is a GitHub Bot account, or whose login ends in `[bot]` or starts
with `app/`.

## Other commands

- `$DESK tick` — one pass. Add `--dry-run` to fetch and render `queue.md`
  without spawning, cmux calls, or saving state.
- `$DESK prune` — print `wt remove` commands for worktrees of filed, taken,
  dropped, and dismissed PRs that are still around (older reviews, or ones that
  failed removal). Run them only with `--yes`, and only when the user asks.

## Files

- `~/.local/state/review-desk/state.json` — per-PR state, keyed `owner/repo#n`
- `~/.local/state/review-desk/queue.md` — the dashboard (live-reloads in cmux)
- `~/.local/state/review-desk/verdicts/<owner>-<repo>-<n>.md` — written by
  `/review-pr` or `/review-migration-pr` when launched with `--desk`; its arrival flips the PR to `verdict-ready`

## Requirements

- Ruby; run every command through `scripts/review-desk.sh`, which installs the
  gems in `scripts/Gemfile` that `watch` needs for the active Ruby. Every other
  command is standard library only. `gh` authenticated with
  `read:org` for team lookups, `wt` (worktrunk), and cmux for the workspace (the
  script skips cmux calls when `CMUX_SOCKET_PATH` is unset).
- The dashboard listener is Falcon (Async fibers), started by `watch`.
