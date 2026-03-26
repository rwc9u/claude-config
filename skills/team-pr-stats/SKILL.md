---
name: team-pr-stats
description: This skill should be used when the user asks to "show team PR stats", "how many PRs did the team merge", "PR metrics by developer", "team merge activity", "developer PR counts", "team output", "PRs merged per month", "compare team PR activity", or wants to see merged pull request counts per team member over time.
---

# Team PR Stats

Track and display merged pull request counts per developer across a GitHub organization, broken down by month.

## When to Use

Invoke this skill when the user wants to:
- See how many PRs each team member merged over a time period
- Compare team output month over month
- Get PR merge metrics for a specific repo or across all org repos
- Export team PR data as CSV for spreadsheets

## How to Use

### 1. Gather Parameters

You need two required pieces of information:

- **Org**: The GitHub organization (e.g., `Kajabi`)
- **Team**: A list of GitHub usernames and display names

Check the user's teammates file at `~/dev/claude-config/teammates.md` for username mappings. Ask the user which team or individuals they want to track if not specified.

### 2. Run the Script

Execute the bundled Ruby script with the required parameters:

```bash
ruby "${SKILL_DIR}/scripts/team-pr-stats.rb" \
  --org <ORG> \
  --team "<user1>:<Name 1>,<user2>:<Name 2>" \
  [--months N] \
  [--repo <repo-name>] \
  [--csv]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--org` | Yes | — | GitHub organization name |
| `--team` | Yes | — | Comma-separated `username:Display Name` pairs |
| `--months` | No | 3 | Number of months to look back |
| `--repo` | No | all org repos | Specific repo to scope to |
| `--csv` | No | false | Output as CSV instead of markdown table |

### Examples

**Production Engineering team, last 3 months, all repos:**
```bash
ruby "${SKILL_DIR}/scripts/team-pr-stats.rb" \
  --org Kajabi \
  --team "allantaylor8907:Allan Taylor,andrewdupont:Andrew Dupont,john-kajabi:John Huynh,orrjosh:Josh Orr,ktsalz:Katie Borisov,kenmgrimm:Ken Grimm,thunderd0m3:Nick Dome,prsimp:Paul Simpson,rwc9u:Rob Christie"
```

**Single developer, specific repo, 6 months:**
```bash
ruby "${SKILL_DIR}/scripts/team-pr-stats.rb" \
  --org Kajabi \
  --team "rwc9u:Rob Christie" \
  --months 6 \
  --repo kajabi-products
```

**CSV output for spreadsheet import:**
```bash
ruby "${SKILL_DIR}/scripts/team-pr-stats.rb" \
  --org Kajabi \
  --team "rwc9u:Rob Christie,prsimp:Paul Simpson" \
  --csv
```

### 3. Present the Results

The script outputs a markdown-formatted table (or CSV with `--csv`). Progress messages go to stderr so they don't pollute the output.

Key things to highlight when presenting results:
- **Top contributors** and their trends
- **Month-over-month changes** (ramp-ups, dips, spikes)
- **Team totals** and averages
- **Contextual notes** (e.g., holiday months, partial month data)

## Requirements

- **Ruby** (standard library only — no gems needed)
- **gh CLI** authenticated with access to the target GitHub org
- Internet connectivity for GitHub API calls

## Notes

- GitHub search API rate limits apply (~30 requests/minute for authenticated users). For large teams with many months, the script may take a minute or two.
- The current month's data will be partial if run mid-month — note this when presenting results.
- Results are sorted by total PRs descending (highest output first).
