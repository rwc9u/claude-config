---
name: open-prs
description: This skill should be used when the user asks to "show my open PRs", "list my PRs", "what PRs do I have open", "PR dashboard", "show PRs I'm reviewing", "my pull requests", "open pull requests", "PR status", or wants to see their open pull requests categorized by age.
---

# Open PRs Dashboard

Display all open pull requests — both authored and reviewing — categorized into three age buckets: active this week, 1–8 weeks, and older.

## When to Use

Invoke this skill when the user wants to:
- See all their open PRs at a glance
- Check which PRs need attention (stale or aging)
- Review their pending review requests
- Get a PR dashboard or status overview

## How to Use

### Run the Script

Execute the bundled Ruby script:

```bash
ruby "${SKILL_DIR}/scripts/open-prs.rb" [--username USERNAME] [--reviewing]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--username` | No | `rwc9u` | GitHub username to query |
| `--reviewing` | No | off | Also show PRs the user is reviewing |

### Output Structure

By default, the script shows only authored PRs in three age-bucket tables:

1. **My Open PRs** — PRs authored by the user
   - Active This Week (updated within 7 days)
   - 1–8 Weeks (created 1–8 weeks ago, not recently active)
   - Older (created more than 8 weeks ago, not recently active)

When `--reviewing` is passed, a second section is added:

2. **PRs I'm Reviewing** — PRs where review was requested or already provided
   - Same three age buckets
   - Excludes PRs authored by the user
   - Combines review-requested and already-reviewed PRs, deduplicated

Only pass `--reviewing` when the user explicitly asks to see PRs they are reviewing.

Each table row includes: repo name, PR link, title, status (Draft/Approved/Changes Requested/Review Required/Open), and last updated date.

### Presenting Results

Present the script's markdown output directly — all tables, links, and summary line — without additional commentary or analysis. The tables are the deliverable.

## Requirements

- **Ruby** (standard library only — no gems needed)
- **gh CLI** authenticated with access to relevant GitHub repos
