---
name: on-call
description: This skill should be used when the user asks for an "on-call report", "on-call summary", "on-call recap", "on-call check", "what happened on-call", "weekly on-call", "daily on-call", "on-call digest", "production engineering on-call", "PE on-call", "summarize on-call activity", or wants a recap of pages, incidents, triage queue, and on-call channel activity for the Production Engineering team across yesterday and the previous week.
---

# On-Call Report

Generate a comprehensive on-call recap for the Production Engineering team covering both **yesterday** and the **previous 7 days**. The report combines Datadog pages and incidents, Linear triage queue state, and Slack activity in the on-call channels (`#prodeng-inbox`, `#production-ops`, `#prodeng-alerts`) into a single situational snapshot.

## When to Use

Invoke this skill when the user wants to:
- Catch up after a stretch off rotation
- Prepare for an on-call handoff
- Review what fired/paged for Production Engineering recently
- See the current state of the PE Linear triage queue
- Get a summary of incidents created in the last day or week
- Understand request volume and themes in `#prodeng-inbox`
- Spot-check noise in `#prodeng-alerts` or recurring topics in `#production-ops`

## Step 1: Determine the Target Date Ranges

The skill always reports on **two windows**:

1. **Yesterday window** — the previous workday
   - If today is **Monday** → previous workday is **Friday**; also include weekend (Saturday + Sunday) in the "yesterday" bucket since pages/incidents happen on weekends too
   - If today is **Tuesday–Friday** → previous workday is **yesterday**
   - If today is **Saturday/Sunday** → previous workday is **Friday**, and include any preceding weekend days up through "yesterday"
2. **Previous 7 days window** — `today - 7 days` through `today` (inclusive), used for the weekly view

Compute and store:
- `YESTERDAY_START` and `YESTERDAY_END` as ISO timestamps (UTC) covering the yesterday window
- `WEEK_START` and `WEEK_END` as ISO timestamps (UTC) covering the trailing 7-day window
- `YESTERDAY_LABEL` (e.g., "Friday, May 22") and `WEEK_LABEL` (e.g., "May 15 – May 22")

Tell the user: "Generating on-call report for **[YESTERDAY_LABEL]** and the past 7 days (**[WEEK_LABEL]**)…"

If the user provided an explicit scope (e.g., "just yesterday's on-call", "weekly on-call only"), produce only the relevant section.

## Step 2: Gather Data in Parallel

Launch **three sub-agents in parallel**, each responsible for one data domain. All three should run concurrently in a single message containing multiple `Agent` tool calls.

### 2a. Datadog Sub-Agent (Pages + Incidents)

Launch an Agent (`subagent_type: "general-purpose"`) with the prompt below. Pass `YESTERDAY_START`, `YESTERDAY_END`, `WEEK_START`, `WEEK_END` into the prompt.

**Agent prompt:**

> You are gathering Datadog data for the Production Engineering on-call report. You need two things for **two time windows** (yesterday and the trailing 7 days):
>
> 1. **Pages** — monitor alerts triggered for the `production-engineering` team
> 2. **Incidents** — incidents created and tagged to the team
>
> **Before doing anything else, perform Datadog skill discovery in parallel:**
> - Call `load_datadog_skill` with `skill_name='datadog/monitors'`
> - Call `load_datadog_skill` with `skill_name='datadog/incidents'`
> - Call `load_datadog_skill` with `skill_name='datadog/events'`
> - Call `list_datadog_skills` with `query='on-call team monitors incidents'`
>
> Follow guidance from any skills that load. If a skill points to related skills (e.g., `datadog/visualizations`), load those as well.
>
> **Determining the team tag.** The Production Engineering team's Datadog tag is one of:
> - `team:production-engineering`
> - `team:prodeng`
> - `team:production_engineering`
>
> First try `team:production-engineering`. If queries return zero results across both windows, try `team:prodeng`, then `team:production_engineering`. Use whichever returns matches and note the resolved tag in your output.
>
> **Pages (triggered monitors).** Use `search_datadog_events` (event source = `alert` / monitor events) or the appropriate monitor-events tool surfaced by the loaded skill. Query the team tag and filter for alert-triggered states (status: error/warn/alert/triggered). Run two queries in parallel:
> - Yesterday: `from = YESTERDAY_START`, `to = YESTERDAY_END`
> - Past 7 days: `from = WEEK_START`, `to = WEEK_END`
>
> For each page, capture: monitor name, monitor URL/ID, triggered time, severity/priority, count of occurrences if grouped, and any tag context useful for theming (service, env).
>
> **Incidents.** Use `search_datadog_incidents` (or whichever incident-search tool the incidents skill specifies). Filter by the team tag and `created_at` within each window. Run two queries in parallel. For each incident capture: title, ID/URL, severity, status, created_at, commander/lead if available.
>
> **Process and summarize.** For each window, separately:
> 1. **Pages** — group by monitor name. For each unique monitor: priority (P1–P5, or Warn if no P-tag), count of triggers, first/last fire time, summary of the alert. Then **segregate into three priority buckets**:
>    - 🚨 **P1 / P2 — Real signal** (customer-impacting, on-call attention-grade)
>    - ⚠️ **P3 — Worth attention** (degradation, recurring issues)
>    - 🔇 **P4 / P5 / Warn — Background noise** (low-severity, often tunable)
>    Within each bucket, sort by trigger count desc, then most recent. Determine priority from the monitor name prefix (`[P1]`, `[P2]`, `[P3]`, `[P4]`, `[P5]`) or from the event priority field; if neither is present, classify as Warn.
> 2. **Noise vs signal** — flag any monitor that fired 5+ times in the window as "noisy" with a 🔁 marker.
> 3. **Incidents** — list each with severity and current status. If an incident is still open/active, mark with ⚠️.
> 4. **Top themes** — 1–3 short bullets describing what the noise was about. Lead with the highest-severity theme, not the highest-volume one. Volume goes in counts; severity belongs in themes.
>
> **Return format (exact):**
>
> ```
> ## Datadog
> Resolved team tag: <tag used>
>
> ### Yesterday — 🚨 P1 / P2 Pages — Real signal
> - **[P<N>] <monitor name>** (Nx fired) — first: <time MT>, last: <time MT>
>   <short summary> [link]
>   <🔁 if noisy>
> _If none: "_None_"_
>
> ### Yesterday — ⚠️ P3 Pages — Worth attention
> - same shape
> _If none: "_None_"_
>
> ### Yesterday — 🔇 P4 / P5 / Warn Pages — Background noise
> - same shape
> _If none: "_None_"_
>
> ### Yesterday — Incidents
> - **<title>** [<id>] — sev: <sev>, status: <status>, created: <time MT> <⚠️ if open>
>   <link>
>
> ### Past 7 Days — 🚨 P1 / P2 Pages — Real signal
> (same shape as yesterday)
>
> ### Past 7 Days — ⚠️ P3 Pages — Worth attention
> (same shape as yesterday)
>
> ### Past 7 Days — 🔇 P4 / P5 / Warn Pages — Background noise
> (same shape as yesterday)
>
> ### Past 7 Days — Incidents
> (same shape as yesterday)
>
> ### Top Themes
> - <theme bullet — lead with highest severity>
> - <theme bullet>
>
> ### Counts
> | Bucket | Monitors | Fires | Noisy (5+) |
> |---|---|---|---|
> | P1/P2 | N | N | N |
> | P3 | N | N | N |
> | P4/P5/Warn | N | N | N |
> | **Total** | **N** | **N** | **N** |
> Yesterday Incidents: N (open: K)
> Past 7d Incidents: N (open: K)
> ```
>
> If a domain returns zero results, still include the section with "_None_". If the team tag cannot be resolved (all three candidates returned nothing for both windows), output a clear note explaining that and skip the section.

### 2b. Slack Sub-Agent (on-call channels)

Launch an Agent (`subagent_type: "general-purpose"`) with the prompt below. Pass `YESTERDAY_START`, `YESTERDAY_END`, `WEEK_START`, `WEEK_END` into the prompt.

**Agent prompt:**

> You are gathering Slack activity for the Production Engineering on-call report. You need to read three channels for **two time windows** (yesterday and the trailing 7 days):
>
> - `#prodeng-inbox` — incoming requests / questions for the team
> - `#production-ops` — operations discussion, ongoing issues, customer-facing events
> - `#prodeng-alerts` — automated alerts / monitor notifications
>
> **For each channel, run the following in parallel** (one `slack_read_channel` per channel per window, so 6 calls in parallel):
> - `channel`: the channel name (e.g., `#prodeng-inbox`)
> - `oldest`: window start
> - `latest`: window end
> - `limit`: 200
> - `include_threads`: true if supported by the tool
>
> If `slack_read_channel` is not available or returns nothing, fall back to `slack_search_public_and_private` with queries like:
> - `in:#prodeng-inbox after:<window_start_date> before:<window_end_date+1>`
> - `in:#production-ops after:... before:...`
> - `in:#prodeng-alerts after:... before:...`
>
> **Processing rules per channel:**
>
> **`#prodeng-inbox` — focus on requests.** For each window:
> - Group messages into distinct request threads (top-level message + replies).
> - For each request, write a 1-sentence summary: who asked, what they need, and resolution state.
> - **Determine resolution state from in-thread evidence**: look for explicit resolution language ("fixed", "resolved", "merged", "thanks, addressed", "no longer needed", "✅", "📦"), referenced PRs being merged, Linear issues being created/assigned, or a clear follow-up that closes the loop. **When in doubt, treat as resolved if the thread has substantive replies and no open question** — only mark ⏳ when something is genuinely awaiting a response or action.
> - **Do NOT drop resolved items.** They are part of the weekly activity record. Categorize them, don't delete them.
> - **Split output into two subsections per window**:
>   - **Open / needs follow-up ⏳** — items still awaiting a response, decision, or action.
>   - **Resolved (no action needed) ✅** — items that were handled, merged, addressed, or were purely informational.
> - Pure status / acknowledgement chatter with no underlying request can still be skipped.
>
> **`#production-ops` — focus on incidents and customer-impacting issues.** For each window:
> - Identify distinct issue threads.
> - For each, write a 1-sentence summary covering: what was impacted, root-cause direction (if discussed), resolution status.
> - Highlight unresolved/ongoing items with ⚠️.
>
> **`#prodeng-alerts` — focus on volume and themes, not individual alerts.** For each window:
> - Total message/alert count.
> - Top 3–5 recurring alert sources (group by alert name or first-line pattern).
> - Note any new alert types that didn't appear in the prior window.
> - Do NOT enumerate every alert.
>
> **Return format (exact):**
>
> ```
> ## Slack
>
> ### Yesterday — #prodeng-inbox
> - <one-line request summary> <⏳ if open>
> - …
>
> ### Yesterday — #production-ops
> - <one-line issue summary> <⚠️ if ongoing>
> - …
>
> ### Yesterday — #prodeng-alerts
> Total alerts: N
> Top sources:
> - <alert source> — N
> - <alert source> — N
>
> ### Past 7 Days — #prodeng-inbox
> (same shape; consolidate so threads aren't double-counted)
>
> ### Past 7 Days — #production-ops
> (same shape)
>
> ### Past 7 Days — #prodeng-alerts
> Total alerts: N
> Top sources:
> - <alert source> — N
> New alert types this week (not in yesterday):
> - <alert source>
>
> ### Counts
> Inbox requests (yesterday / 7d): N / N (open: K / K)
> Ops issues (yesterday / 7d): N / N (ongoing: K / K)
> Alert volume (yesterday / 7d): N / N
> ```
>
> If any channel returns errors or is inaccessible, note it with a clear "_Could not read #channel-name: <reason>_" and continue with the others.

### 2c. Linear Sub-Agent (Triage queue)

Launch an Agent (`subagent_type: "general-purpose"`) with the prompt below.

**Agent prompt:**

> You are gathering the Linear triage queue state for the Production Engineering on-call report.
>
> **Step 1 — Resolve the team.** Call `list_teams` and find the team whose name matches **"Production Engineering"** (case-insensitive, also accept variations like "ProdEng" or "PE"). Capture its `id` and `key`.
>
> **Step 2 — List Triage issues.** Call `list_issues` filtered to:
> - The PE team `id`
> - Status type / workflow state: `triage` (use `list_issue_statuses` for the team first if you need the exact state id for the Triage state)
> - Order by `createdAt` desc
> - `limit`: 100
>
> For each Triage issue capture: identifier (e.g., `PE-1234`), title, URL, priority, createdAt, requester (creator name), age in days, label set (filter out non-meaningful labels).
>
> **Step 3 — Bucket by age**:
> - **New (≤24h)** — created within `YESTERDAY_START..now`
> - **This week (1–7d)** — created within `WEEK_START..YESTERDAY_START`
> - **Older backlog (>7d)** — created before `WEEK_START`, still in Triage
>
> **Step 4 — Surface themes.** Look at titles + labels and propose 1–3 short bullets summarizing what kinds of issues are sitting in triage (e.g., "Several flaky-spec reports", "Multiple alerting noise complaints").
>
> **Return format (exact):**
>
> ```
> ## Linear Triage — Production Engineering
> Team: <Name> (<KEY>)
>
> ### New (≤24h)
> - [PE-XXXX](url) — title — priority: <P> — by <requester> — <age>
> - …
>
> ### This week (1–7d)
> - [PE-XXXX](url) — title — priority: <P> — by <requester> — <age>
> - …
>
> ### Older backlog (>7d, still in Triage)
> - [PE-XXXX](url) — title — priority: <P> — by <requester> — <age>
> - …
>
> ### Themes
> - <theme>
> - <theme>
>
> ### Counts
> Triage New (≤24h): N
> Triage This Week (1–7d): N
> Triage Older Backlog (>7d): N
> Total in Triage: N
> ```
>
> If the team cannot be resolved, return:
> ```
> ## Linear Triage — Production Engineering
> _Could not resolve Production Engineering team in Linear. Teams searched: <list>_
> ```

## Step 2.5: Attribute P1/P2 Pages to Known Causes

After the three sub-agents return, but **before** compiling the final report, do one more pass to attribute each 🚨 P1/P2 page to a known cause if one exists.

For each P1/P2 page (use the first/last fire times from the Datadog output):

1. **Check the Slack output** for human discussion in `#prodeng-inbox`, `#production-ops`, or `#prodeng-alerts` threads that overlap the page's time window (±2 hours). Look for explicit attribution language: "maintenance", "deploy", "migration", "stuck", "rollback", "incident #X", or references to PRs / Linear issues that explain the cause.
2. **Check the Linear output** for incidents created in the same time window that might be the underlying cause.
3. **Check declared Datadog incidents** (even on other teams) whose timing overlaps — they may be the cause even when not tagged PE.
4. **If still unattributed**, optionally ask the user a short clarifying question (one sentence: "Do you know what caused the [page name] at [time MT]?"). Skip the question if the page is sub-minute or already auto-recovered.

Annotate each P1/P2 entry with one of:
- ✅ **explained: <short cause>** — root cause known (maintenance, deploy, migration, planned change, prior incident)
- ⚠️ **unexplained** — no attribution found; this is what actually deserves investigation

**Do not auto-suggest an RCA for an event that's already explained.** "Suggested Next Actions" should treat ✅-annotated events as resolved unless there's a forward-looking ask (e.g., "add a playbook entry for the stuck-migration case").

## Step 3: Compile the Final Report

Wait for all three sub-agents to complete and the attribution pass to finish, then assemble the final report in this exact order:

```
# On-Call Report — <YESTERDAY_LABEL> & past 7 days (<WEEK_LABEL>)

## TL;DR
- 4–6 bullets synthesizing the most important takeaways across Datadog, Slack, and Linear.
- Prioritize: open incidents, ongoing #production-ops issues, noisy monitors, aging triage items, recurring themes.
- Each bullet one sentence. Outcome-focused, not raw counts.

## Yesterday Snapshot
| Category | Count |
|----------|-------|
| 🚨 P1/P2 Pages (monitors) | N (M) |
| ⚠️ P3 Pages (monitors) | N (M) |
| 🔇 P4/P5/Warn Pages (monitors) | N (M) |
| Incidents Created (open) | N (K) |
| #prodeng-inbox requests (open) | N (K) |
| #production-ops issues (ongoing) | N (K) |
| #prodeng-alerts volume | N |
| New Triage items (≤24h) | N |

## Past 7 Days Snapshot
| Category | Count |
|----------|-------|
| 🚨 P1/P2 Pages (monitors) | N (M) |
| ⚠️ P3 Pages (monitors) | N (M) |
| 🔇 P4/P5/Warn Pages (monitors) | N (M) |
| Incidents Created (open) | N (K) |
| #prodeng-inbox requests (open) | N (K) |
| #production-ops issues (ongoing) | N (K) |
| #prodeng-alerts volume | N |
| Triage items added (1–7d) | N |
| Triage older backlog (>7d) | N |

---

[Paste Datadog sub-agent output here verbatim]

---

[Paste Slack sub-agent output here verbatim]

---

[Paste Linear sub-agent output here verbatim]

---

## Suggested Next Actions
- 2–6 specific, actionable suggestions based on the data.
- **Skip RCA suggestions for ✅-attributed P1/P2 events.** They're explained; surface forward-looking asks instead ("Add a runbook entry for the stuck-migration case").
- **Prioritize ⚠️-unattributed P1/P2 events** — these are the genuine unknowns worth investigating.
- Other action types: noise reduction (silencing / fixing chronic monitors), open inbox follow-ups, aging triage items, declared-but-still-open incidents.
- Example shape:
  - "Investigate the ⚠️-unattributed [page name] at [time MT]"
  - "Fix recurring noise on monitor X (fired Y times this week)"
  - "Follow up on open #prodeng-inbox request from <person> about <topic>"
  - "Triage aging PE-XXXX (N days in queue)"
```

## Notes & Conventions

- **Graceful degradation**: If any source returns errors, note it inline (e.g., "_Could not retrieve Datadog incidents: <reason>_") rather than failing the whole report.
- **No raw dumps**: Always summarize. The deliverable is signal, not a paste of every alert.
- **Markdown links**: Always link issues, incidents, and monitors back to their source for one-click drill-in.
- **Time zone**: Treat times as UTC for queries but render to the user in **Mountain Time** (`America/Denver`). Detect the user's actual local timezone at the start of the run with `date +"%Z %z"` and use that if it differs — never silently assume Central or any other zone. Use the `MT` label (or whatever zone is detected) consistently in all rendered timestamps.
- **Custom windows**: If the user asks for a custom window (e.g., "last 3 days", "since Monday"), substitute that for the 7-day window but keep the yesterday section as-is unless they explicitly drop it.
- **Channel access**: If `#production-ops`, `#prodeng-inbox`, or `#prodeng-alerts` aren't joinable by the Slack tool, surface the error clearly so the user can fix access — don't silently omit the section.

## Requirements

- **MCP servers**: `datadog-mcp`, `linear-server` (or `plugin:flexops:linear-server`), and a Slack MCP (`slack` or `plugin:slack:slack`) must be connected and authenticated.
- **Datadog skill discovery**: The Datadog MCP server ships skill guides — the Datadog sub-agent must perform skill discovery before running queries (per the MCP server's own instructions).
- **Linear team access**: The user must have read access to the Production Engineering team in Linear.
