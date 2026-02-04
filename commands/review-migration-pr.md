---
description: Review a migration PR from kajabi-products with the branch checked out locally
allowed-tools: Bash, Read, Glob, Grep, Task
---

# Review Migration PR

You are tasked with reviewing a migration Pull Request for the kajabi-products repository.

## Prerequisites

This command assumes:
- The kajabi-products repository is available locally
- The migration branch has been (or will be) checked out locally for review

## Required Prompt

**YOU MUST LOAD** the following file before performing the migration review:

```
~/dev/kajabi-products/docs/prompts/database_migration_analysis_prompt.md
```

Read this file first and follow its instructions for analyzing database migrations. The guidelines in that file take precedence over the general review steps below.

## Process

### 1. Determine kajabi-products Location

Check for kajabi-products in common locations:
- `~/dev/kajabi-products`
- `~/code/kajabi-products`
- The current directory if it appears to be kajabi-products

If not found, ask the user for the path.

### 2. Check Current Branch State

Navigate to the kajabi-products directory and run:
- `git branch --show-current` to check current branch
- `git status` to see working tree state

**If currently on `main` or `master`:**

Ask the user which approach they prefer:

> The repository is currently on the main branch. Would you like to:
> 1. **Check out the PR branch directly** - Provide the branch name and I'll run `git checkout <branch>`
> 2. **Use `wt` (Worktrunk) to create a worktree** - This keeps your main workspace clean. I'll run `wt add <branch>` to create an isolated worktree for the review
>
> Which approach do you prefer? Also, please provide the branch name for the migration PR.

Wait for user response before proceeding.

### 3. Ensure Branch is Up to Date

Once on the correct branch:
```bash
git fetch origin
git log --oneline -5  # Show recent commits
git diff --stat origin/main...HEAD  # Show what's changed vs main
```

### 4. Identify Migration Files

Search for migration-related changes:
```bash
# Find new/modified migration files
git diff --name-only origin/main...HEAD | grep -E "db/migrate"

# Find any schema changes
git diff origin/main...HEAD -- db/schema.rb
```

### 5. Review Migration Files

For each migration file found:
1. **Read the full migration file**
2. **Check for:**
   - Proper `up` and `down` methods (or reversible `change`)
   - Safe operations (no data loss without explicit handling)
   - Appropriate use of `safety_assured` blocks if using strong_migrations
   - Index additions for foreign keys
   - Null constraints and default values
   - Large table considerations (batching, timeouts)

### 6. Migration-Specific Checks

Review for these common migration concerns:

#### Safety
- [ ] Does this migration lock tables for extended periods?
- [ ] Are there any operations on large tables that could cause downtime?
- [ ] Is `safety_assured` used appropriately (not bypassing legitimate warnings)?
- [ ] Are there any irreversible operations without proper handling?

#### Data Integrity
- [ ] Are foreign key constraints properly defined?
- [ ] Are null/not-null constraints appropriate?
- [ ] Are default values sensible?
- [ ] Is existing data handled correctly during the migration?

#### Performance
- [ ] Are indexes added for columns used in WHERE clauses or JOINs?
- [ ] Are composite indexes in the correct column order?
- [ ] Are there any redundant indexes?

#### Reversibility
- [ ] Can this migration be rolled back safely?
- [ ] Is the `down` method correct (if using up/down)?
- [ ] Does the `change` method use only reversible operations?


### 9. Provide Review Summary

Format your review as:

```
## Migration PR Review: [Branch Name]

### Migration Files Reviewed
- `db/migrate/YYYYMMDDHHMMSS_migration_name.rb`

### Summary
[Brief description of what the migration does]

### Safety Assessment
**Risk Level**: [LOW / MEDIUM / HIGH]
[Explanation of risk factors]

### Findings

#### Concerns/Issues
- [Specific issue 1]
- [Specific issue 2]

#### Suggestions
- [Improvement suggestion 1]
- [Improvement suggestion 2]

### Checklist Results
- [ ] Safe for production deployment
- [ ] Reversible without data loss
- [ ] Indexes appropriate
- [ ] Model changes aligned
- [ ] Tests adequate

### Recommendation
**[APPROVE / REQUEST CHANGES / NEEDS DISCUSSION]**

[Explanation of recommendation]
```

## Important Notes

- Always read the FULL migration file, not just the diff
- Consider the production database size when assessing risk
- Check if strong_migrations gem is in use and respect its warnings
- Look for any data migrations mixed with schema migrations (generally discouraged)
- Consider deployment order if there are multiple PRs in flight
