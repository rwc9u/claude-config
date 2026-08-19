# Git & PR Workflow Guidelines

## Git Conventional Commits Rules

### Commit Format
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding/modifying tests
- `chore`: Maintenance tasks

### Scope Determination
- Automatic from file paths: `models`, `controllers`, `services`, `specs`, etc.
- Component-based for larger changes: `user-auth`, `payment-processing`

### Smart Description Generation
- **feat**: "add [functionality]"
- **fix**: "resolve [issue description]"
- **refactor**: "extract [component/method]"
- **test**: "add specs for [component]"

### Commit Body Structure
- **Default to two paragraphs** for commit message bodies, in this order:
- **First paragraph**: Context and problem description - what problem we're solving and how it was discovered
- **Second paragraph**: Solution approach - what we did to solve it and why we chose that approach
- **Trivial commits are exempt**: typo fixes, single-line changes, mechanical renames, lockfile bumps, and formatting-only commits can use one paragraph or a subject line alone. Never pad to reach two paragraphs — if the second paragraph would only restate the first or narrate the diff, drop it. The two-paragraph default exists to capture a "why" worth writing down, not to hit a length
- **Line Wrapping**: Wrap body paragraph lines at 80 characters
  - Insert line break before the word that would exceed 80 characters
  - Continue text on the next line without indentation
  - Exception: Long URLs or other non-breakable content can exceed 80 characters
  - This rule applies ONLY to body paragraphs, not the subject line
- **Writing Style**: Write like a human, not a robot. Keep descriptions high-level and provide context that helps other developers understand the "why" behind the change, not just technical implementation details. Avoid overly technical jargon or step-by-step code explanations.

## Branch Workflow

### Creating Branches with Remote Tracking
```bash
# Create a new branch and push to set up remote tracking
git checkout -b <branch-name>
git push -u origin <branch-name>
```

### Deleting Branches (Local and Remote)
```bash
# Delete local branch
git branch -d <branch-name>

# Delete remote branch
git push origin --delete <branch-name>

# Or do both in sequence
git branch -d <branch-name> && git push origin --delete <branch-name>
```

### Branch Naming Convention
- **Pattern**: `<initials>/<feature-nameNN-task-name>`
- **feature-name**: Short 2-3 word description of larger feature being worked on
- **NN**: Branch sequence number with zero-padding (01, 02, 03, etc.) for stacked PRs
- **task-name**: Short 2-3 word description of specific task/sub-task for this branch
- **Examples**: `rc/timezone-fix01-admin-dropdown`, `rc/user-auth02-oauth-integration`
- **No ticket ID in the branch name.** This is deliberate, but it means Linear
  will not auto-attach the PR to its issue — you must attach it explicitly.
  See [pr-workflow.md](pr-workflow.md#attach-the-pr-to-linear).

### Rebasing with `--onto` (Stacked Branches / Merged Base)

Use `git rebase --onto` when a branch's base has been merged to main and a
normal rebase would introduce duplicate commits.

**When to use:**
- Your branch was based on another feature branch that has since been merged
- You need to move commits to a new base without replaying already-merged work

**How to use:**
```bash
# First checkout branch-b
# Always fetch to ensure you have the latest main — a stale local main
# will cause unnecessary conflicts with already-merged work
git fetch origin main
# Run git log and copy the SHA of the commit right before the first
# commit of branch-b (SHA-0)
git rebase --onto origin/main SHA-0 branch-b
# Essentially this rebases your branch-b on origin/main but cuts out
# everything from branch-b from SHA-0 and older
```

This replays only the commits unique to your branch onto `main`, avoiding
duplicates from the already-merged base branch.

**After rebasing onto, you'll need to force push:**
```bash
git push --force-with-lease origin branch-b
```

**Conflict resolution:** During the rebase, if conflicts arise on files that
were changed in both the merged base and your branch, take your branch's
version if the base changes are already in main.

### Checking if a Branch Has Been Merged

**Always check GitHub PR state first** — do not rely solely on git-level checks.

Git-level commands like `git branch --merged` and `git cherry` fail to detect
squash-merged or rebase-merged branches because the resulting commit SHAs on
main differ from the original branch commits.

**Preferred approach:**
```bash
# Check if a PR exists for the branch and its merge state
gh pr list --state merged --head <branch-name>
```

**Why git-level checks are unreliable:**
- `git branch -r --merged origin/main` — only finds branches whose commits are
  direct ancestors of main. Squash merges create new SHAs, so the branch won't
  appear as merged.
- `git cherry origin/main HEAD` — compares patch IDs. Squash merges that combine
  multiple commits change the patch signature, so commits show as unmerged.

**When to use each:**
- **`gh pr list --state merged --head <branch>`** — use this first, works
  regardless of merge strategy (squash, rebase, or merge commit)
- **`git branch --merged`** — only reliable for standard merge commits
- **`git cherry`** — only reliable for single-commit branches that were
  rebase-merged without modification

## Fetching & Pulling Safely

### Never Do Shallow Fetches or Clones

**Always fetch, pull, and clone with full history.** Shallow operations truncate
the commit graph and corrupt local copies of remote-tracking branches. The
symptoms look alarming but have a mundane cause:

- Local `main` shows as **diverged from `origin/main`** even though no one
  force-pushed (branch protection makes that nearly impossible) — the local
  history is simply incomplete, not actually divergent.
- `git blame` attributes lines to the wrong author, or collapses everyone onto a
  single commit, because the older commits that actually touched those lines were
  never fetched.
- Rebases and merges hit phantom conflicts against already-merged work.

**Forbidden flags** on `git clone`, `git fetch`, and `git pull` — these create or
extend a shallow repository:
- `--depth=<n>` (including `--depth 1`)
- `--shallow-since=<date>`
- `--shallow-exclude=<ref>`

Do **not** interrupt a `git fetch`/`git pull` midstream either. A command cut off
before it finishes can leave remote-tracking refs in a non-atomic,
partially-updated state that produces the same diverged-branch symptoms.

**If you think you genuinely need a shallow operation** — for example, a one-off
on a very large repo where fetching full history is impractical — stop and ask
first, explaining why. Never run a shallow fetch/clone silently; full history is
always the default.

### Detecting and Fixing a Shallow Repository

```bash
# Check whether the current repo is shallow (prints "true" if it is)
git rev-parse --is-shallow-repository

# Restore the full history when it is shallow
git fetch --unshallow origin
```

After `--unshallow`, the spurious divergence with `origin/main` disappears and
`git blame` reports correct authorship again.

## Quality Checks
- Ensure descriptions are in imperative mood
- Limit first line to 72 characters for commits
- Use consistent scope naming
- Avoid generic terms like "update" or "change"
- Follow the branch naming convention strictly
