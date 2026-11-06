---
name: disk-usage
description: This skill should be used when the user asks to "clean up disk", "free up disk space", "disk usage", "disk is full", "what's using my disk", "prune worktrees", "delete merged branches", "clean up old branches", or invokes /disk-usage. Prunes merged and dead worktrees/branches with worktrunk (`wt`), then audits caches, runtimes, Docker, simulators, and other space hogs and recommends what to remove.
---

# Disk Usage Cleanup

Free disk space in two phases: prune worktrees and branches with `wt` first (the
biggest win — each kajabi-products worktree is ~0.5–1.6 GiB), then audit the rest
of the machine and recommend. Never delete anything without the user's go-ahead.

## How to Work

- **Iterate in batches.** Present one batch, get a yes, act, report freed space,
  then build the next batch. Don't run a long analysis before showing anything.
- **Keep every command fast.** Never `du` all of `~` or `~/Library` in one shot;
  size named directories in parallel with `timeout`. If a step will take more than
  a minute, say so first.
- **Report `df -h /System/Volumes/Data` before and after each batch.** On macOS the
  `/` line is the read-only system volume; the Data volume is the real number.
- Scratch files (JSON exports, batch lists) go in the session scratchpad.

## Phase 1: Worktrees and Branches (`wt`)

Use `wt`, never `git worktree`. Run per repo, starting with `~/dev/kajabi-products`.

### 1. Snapshot

```bash
df -h /System/Volumes/Data | tail -1
wt list                                       # quick table for the user
wt list --branches --format=json > wt.json    # slow (~minutes on 400+ branches); run in background
```

JSON shape: `.items[]` with `.branch`, `.worktree` (null for branch-only),
`.worktree.changes.{staged,modified,untracked,deleted,conflicted}`,
`.display.state`, `.upstream.ahead` (null upstream = remote branch deleted).

`display.state` values: `integrated` (⊂, content in main), `empty` (_),
`would_conflict` (✗), `diverged` (↕), `ahead`, `behind`, `is_main`.

```bash
# Count by kind / state / dirty
jq -r '.items[] | [(if .worktree then "wt" else "br" end), (.display.state//"none"),
  (if .worktree then ((.worktree.changes|[.staged,.modified,.untracked,.deleted,.conflicted]|any)|tostring) else "-" end)]
  | @tsv' wt.json | sort | uniq -c | sort -rn
```

### 2. Batch 1 — clean + integrated worktrees

Worktrees with `state == "integrated"` and no working-tree changes. Safe; ask, then:

```bash
xargs wt remove -y --foreground < batch1.txt
```

`wt remove` stops the worktree server, removes the directory, and deletes the
local branch. Remote branches are untouched.

### 3. Batch 2 — squash-merged / closed worktrees

**Squash merges show as ✗ or ↕, not ⊂.** Look up the PR for every remaining
non-main worktree:

```bash
while read b; do
  s=$(gh pr list --head "$b" --state all --limit 1 --json number,state,updatedAt \
      -q '.[0] | "\(.state)\t#\(.number)\t\(.updatedAt[:10])"')
  printf "%s\t%s\n" "${s:-NO_PR}" "$b"
done < candidates.txt
```

Before proposing removal, flag any with **unpushed commits** (`upstream.ahead > 0`)
or uncommitted changes — hold those back and ask individually. CLOSED-unmerged PRs
are recoverable from GitHub via the PR ref even if the remote branch is gone; say so.

Remove approved MERGED/CLOSED ones with `-D` (squash-merged branches need force):

```bash
xargs wt remove -y -D --foreground < batch2.txt
```

Never touch OPEN-PR worktrees or dirty worktrees without explicit say-so.
Also list old-style sibling worktrees (`~/dev/<repo>.<branch>`) tied to stale open
PRs as a recommendation, not an action.

### 4. Branch-only refs

Negligible disk, but worth tidying. Build the list of branches with no worktree and
look up PR state in parallel. **Use `xargs -n1 -P10 sh -c '…' _`, not `xargs -I{}`** —
macOS `-I` fails on long branch names ("command line cannot be assembled").

```bash
git worktree list --porcelain | awk '/^branch /{sub("branch refs/heads/","");print}' | sort > wt_br.txt
git for-each-ref --format='%(refname:short)' refs/heads | sort | comm -23 - wt_br.txt > br_only.txt
xargs -n1 -P10 sh -c 's=$(gh pr list --head "$1" --state all --limit 1 --json state -q ".[0].state" 2>/dev/null);
  printf "%s\t%s\n" "${s:-NO_PR}" "$1"' _ < br_only.txt > br_states.tsv
```

Delete MERGED + CLOSED with `git branch -D`. Present NO_PR branches grouped
(integrated / ancient local-only / review checkouts & backups) for the user to decide.

## Phase 2: Machine Audit

Size these in parallel with a timeout, then drill into the big ones:

```bash
for d in ~/Downloads ~/Library/Caches ~/Library/Developer ~/Library/Containers \
  ~/Library/Application\ Support ~/.cache ~/.npm ~/.asdf ~/.local ~/.claude ~/dev; do
  [ -e "$d" ] && (timeout 120 du -sh "$d" 2>/dev/null | tail -1) &
done; wait
```

A non-zero `du` exit is usually permission errors, not a timeout — the size line is
still valid. `~/.Trash` is unreadable without Full Disk Access; tell the user to
empty it in Finder.

Then recommend from this checklist, as a table of area / size / action / risk:

| Area | Check | Cleanup |
|-|-|-|
| Homebrew cache | `du -sh ~/Library/Caches/Homebrew` | `brew cleanup -s --prune=all` |
| Yarn cache | `du -sh ~/Library/Caches/Yarn` | `yarn cache clean` |
| npm cache | `du -sh ~/.npm` | `npm cache clean --force` |
| pnpm store | `du -sh ~/Library/Caches/pnpm ~/Library/pnpm/store` | `pnpm store prune` and `pnpm cache delete` (metadata) |
| Other caches | `du -sh ~/Library/Caches/* \| sort -rh \| head` (Cypress, ms-playwright, org.swift.swiftpm, Google), `~/.cache` | Remove the folder; re-downloads on demand |
| asdf runtimes | `ls ~/.asdf/installs/{ruby,nodejs}` vs `cat ~/dev/*/.tool-versions ~/dev/*/.ruby-version ~/.tool-versions` | `asdf uninstall <tool> <ver>` for unreferenced versions |
| Docker | `docker system df` | `docker builder prune`, `docker volume prune`. The VM disk file (`~/Library/Containers/com.docker.docker`) only shrinks on a Docker Desktop disk reset |
| iOS Simulators | `du -sh ~/Library/Developer/CoreSimulator/Devices` | `xcrun simctl delete unavailable` |
| Claude desktop VM | `du -sh ~/Library/Application\ Support/Claude/vm_bundles` | Delete; re-downloads if VM features are used |
| Downloads | `du -sh ~/Downloads` | User reviews |
| Trash | — | Empty in Finder |

**asdf shims need a version:** run `yarn`/`pnpm` from `~/dev` (it pins Node), not
`~`, and set `ASDF_PNPM_VERSION=<installed version>` for pnpm. Otherwise they print
"No version is set" and clean nothing.

Recommend the no-downside rows (caches, Docker prune, simulators) as a default
batch, and run only the rows the user approves. Report freed space after each.
