# What Did I Do Yesterday?

You are tasked with generating a comprehensive summary of what the user accomplished on the previous workday. This combines GitHub activity, Slack messages, Linear ticket activity, and Google Calendar meetings into a single daily recap.

## Step 1: Determine the Target Date

1. Get today's date and day of the week
2. Determine the "previous workday":
   - If today is **Monday**, the previous workday is **Friday**
   - If today is **Tuesday through Friday**, the previous workday is **yesterday**
   - If today is **Saturday**, the previous workday is **Friday**
   - If today is **Sunday**, the previous workday is **Friday**
3. Store the target date in `YYYY-MM-DD` format for use in all queries below
4. If today is **Monday** (or Saturday/Sunday), also store the weekend dates (Saturday and Sunday) as `WEEKEND_SAT` and `WEEKEND_SUN` — these will be used for additional GitHub PR queries
5. Tell the user: "Looking up your activity for **[Day of Week], [Date]**..."
   - If weekend dates are included, add: "Also checking for weekend GitHub activity (Sat/Sun)..."

## Step 2: Gather Data in Parallel

Launch **three sub-agents and one direct call** in parallel:

### 2a. GitHub Activity Sub-Agent

Launch an Agent (subagent_type: "general-purpose") with the following prompt. Pass the computed TARGET_DATE (and WEEKEND_SAT/WEEKEND_SUN if Monday) into the prompt.

**Agent prompt:**

> You are gathering GitHub activity for a daily recap. The user's GitHub username is `rwc9u`. The target date is TARGET_DATE.
>
> Run all of the following `gh` CLI commands in parallel:
>
> ```bash
> gh search prs --author=rwc9u --created=TARGET_DATE --json title,url,state,repository,createdAt --limit 20
> gh search prs --author=rwc9u --merged-at=TARGET_DATE --json title,url,state,repository --limit 20
> gh search prs --reviewed-by=rwc9u --updated=TARGET_DATE --json title,url,state,repository,author --limit 30
> gh search issues --author=rwc9u --created=TARGET_DATE --json title,url,state,repository --limit 20
> gh search commits --author=rwc9u --author-date=TARGET_DATE --json repository,sha,commit --limit 30
> ```
>
> If today is Monday, also run these weekend queries in the same parallel batch:
> ```bash
> gh search prs --author=rwc9u --created=WEEKEND_SAT..WEEKEND_SUN --json title,url,state,repository,createdAt --limit 20
> gh search prs --author=rwc9u --merged-at=WEEKEND_SAT..WEEKEND_SUN --json title,url,state,repository --limit 20
> gh search commits --author=rwc9u --author-date=WEEKEND_SAT..WEEKEND_SUN --json repository,sha,commit --limit 30
> ```
>
> After all results are in, process them:
>
> 1. **PRs reviewed (IMPORTANT — verify, do not guess)**: The `--reviewed-by` search returns candidate PRs but its `--updated` filter is loose, so you MUST verify each one against the reviews API instead of inferring from the search output. Do NOT zero this out or hand-wave it — a non-empty `--reviewed-by` result almost always means real reviews happened.
>    - First drop any candidate where `author.login == rwc9u` (you don't review your own PRs).
>    - For every remaining candidate, call the reviews API to get the real review state and submission date:
>      ```bash
>      gh api "repos/<owner>/<repo>/pulls/<number>/reviews" \
>        --jq '.[] | select(.user.login=="rwc9u") | "\(.state) \(.submitted_at[0:10])"'
>      ```
>      (On Monday, run this for both TARGET_DATE and the WEEKEND_SAT..WEEKEND_SUN range.)
>    - Keep a PR only if `rwc9u` submitted a review whose `submitted_at` date falls within the target window. Record the review `state` (APPROVED / CHANGES_REQUESTED / COMMENTED); a PR may have multiple review rows — treat APPROVED as the headline state if present.
>    - Count each qualifying PR once. If the verified count is 0, double-check the candidate list was actually empty before reporting 0.
> 2. **Commits**: Exclude automated/bot commits (e.g., datadog_dashboards "Changes as of run" commits where the committer is github-actions[bot]).
> 3. **PR summaries**: For each PR created or merged by the user, write a 1-2 sentence summary based on the title and commit message. Focus on "what" and "why", not implementation details.
> 4. **Weekend**: If Monday, keep weekend results in a separate group labeled "Weekend".
>
> Return a structured summary in this exact format:
>
> ```
> ## PRs Created (Friday)
> - [repo#number](url) — title
>   Summary: ...
>
> ## PRs Merged (Friday)
> - [repo#number](url) — title
>   Summary: ...
>
> ## PRs Reviewed (Friday)
> - [repo#number](url) by @author — title [✅ Approved | 🔄 Changes requested | 💬 Commented]
>   Summary: ...
>
> ## Weekend PRs Created (if Monday)
> ...
>
> ## Weekend PRs Merged (if Monday)
> ...
>
> ## Commits
> - N commits to repo/name (excluding bot commits)
>
> ## Weekend Commits (if Monday)
> - N commits to repo/name (excluding bot commits)
>
> ## Issues
> - List any issues created
>
> ## Counts
> PRs Created: N
> PRs Merged (Fri): N
> PRs Merged (Weekend): N
> PRs Reviewed: N
> Commits (non-bot): N
> ```

### 2b. Slack Activity Sub-Agent

Launch an Agent (subagent_type: "general-purpose") with the following prompt. Pass the computed TARGET_DATE into the prompt.

**Agent prompt:**

> You are gathering Slack activity for a daily recap. The user's Slack user ID is `U01C4K5GQLC`. The target date is TARGET_DATE.
>
> Search for messages using `slack_search_public_and_private`:
> - Query: `from:<@U01C4K5GQLC> on:TARGET_DATE`
> - Sort by: `timestamp`
> - Sort direction: `asc`
> - Limit: 20
> - Response format: `concise`
>
> Paginate through all results (up to 60 messages across 3 pages) using the cursor returned in each response.
>
> After collecting all messages, group them by channel/DM and summarize:
>
> Return a structured summary in this exact format:
>
> ```
> ## Slack Activity
>
> **#channel-name** — 1-2 sentence summary of topics discussed
> **#another-channel** — 1-2 sentence summary
> **DM with Person Name** — 1-2 sentence summary of topics
> **Group DM with Person1, Person2** — 1-2 sentence summary
>
> ## Counts
> Total Messages: N
> Channels/DMs Active: N
> ```
>
> If Slack search returns errors or no results, return:
> ```
> ## Slack Activity
> No Slack messages found for TARGET_DATE
>
> ## Counts
> Total Messages: 0
> Channels/DMs Active: 0
> ```

### 2c. Linear Activity Sub-Agent

Launch an Agent (subagent_type: "general-purpose") with the following prompt. Pass the computed TARGET_DATE (and WEEKEND_SAT/WEEKEND_SUN if Monday) into the prompt. This sub-agent uses the Linear MCP tools (`mcp__linear-server__*`) — if they are deferred, load `mcp__linear-server__list_issues` and `mcp__linear-server__get_issue` via ToolSearch first.

**Agent prompt:**

> You are gathering Linear ticket activity for a daily recap. The target date is TARGET_DATE. If a weekend window is provided (WEEKEND_SAT..WEEKEND_SUN), include it too — the goal is every status change in the window TARGET_DATE..WEEKEND_SUN (or just TARGET_DATE if no weekend).
>
> **Goal:** surface tickets whose *status the user changed* during the window — especially ones with NO PR/commit — so the recap can distinguish "moved the board" from "shipped code".
>
> 1. **Fetch candidates.** Call `mcp__linear-server__list_issues` with:
>    - `assignee: "me"`
>    - `updatedAt: TARGET_DATE` (this filters to issues updated on/after the start of the target date, which covers the whole window)
>    - `orderBy: "updatedAt"`
>    - `limit: 100`
>    - `includeArchived: true`
>    Paginate with the returned cursor until `hasNextPage` is false.
> 2. **Identify status changes in the window.** Linear only exposes dedicated timestamps for a few transitions: `startedAt` (moved into a started/In Progress state), `completedAt` (moved to Done/completed), and `canceledAt` (Canceled). For each issue, keep it if any of `startedAt`, `completedAt`, or `canceledAt` falls within the window (compare the date portion). Record which transition fired and its local date.
>    - Moves into states WITHOUT a dedicated timestamp (e.g. Todo, In Review, Backlog, Triage) cannot be dated precisely from this API. If an issue's `updatedAt` is in the window and its current status is one of these but none of the dated fields match, list it under a separate "Possible status changes (unconfirmed timing)" group rather than asserting the date.
> 3. **Cross-reference work.** For each in-window status change, note whether the issue has a linked branch (`gitBranchName`) and whether it looks like code shipped (you will NOT have GitHub data here — just flag whether a git branch name exists and whether the status is Done). The main agent correlates against GitHub/Slack; your job is to flag the "moved to In Progress / In Review with no obvious completion" candidates so it can infer whether real work started.
> 4. **Do NOT** modify any Linear issue. Read-only.
>
> Return a structured summary in this exact format (identifiers as markdown links using each issue's `url`):
>
> ```
> ## Linear Status Changes (Friday)
> - [PE-1234](url) — title → **In Progress** (started HH:MM local or date)
>   Git branch: yes/no · Has completion: no
>   Note: moved to In Progress, no Done state — candidate for "started work, no PR yet"
> - [PE-5678](url) — title → **Done** (completed date)
>   Git branch: yes · Has completion: yes
>
> ## Weekend Linear Status Changes (if Monday)
> ...
>
> ## Possible status changes (unconfirmed timing)
> - [PE-9012](url) — title — current status: In Review — updatedAt date (could not confirm the transition date from the API)
>
> ## Counts
> Moved to In Progress: N
> Moved to Done: N
> Moved to Canceled: N
> Other/unconfirmed: N
> ```
>
> If no issues changed status in the window, return:
> ```
> ## Linear Status Changes (Friday)
> No Linear status changes found for the window
>
> ## Counts
> Moved to In Progress: 0
> Moved to Done: 0
> Moved to Canceled: 0
> Other/unconfirmed: 0
> ```

### 2d. Google Calendar (Direct Call — No Sub-Agent)

While the three sub-agents run, directly call `gcal_list_events`:
- `timeMin`: `TARGET_DATET00:00:00`
- `timeMax`: `TARGET_DATET23:59:59`
- `timeZone`: `America/Denver` (Mountain Time — user's local zone)
- `condenseEventDetails`: true

Render any timestamps to the user in Mountain Time (MT). If you need to confirm the user's actual local timezone, run `date +"%Z %z"` at the start of the command and use whatever it returns instead of hardcoding `America/Denver`.

Filter out:
- All-day events that appear to be holidays, OOO markers, or working location events (include them in a separate note if present)
- Declined events (if status info is available)
- Clockwise lunch blocks

## Step 3: Compile the Summary

Wait for all three sub-agents to complete, then combine their results with the calendar data.

Present the results in this format:

---

## Daily Recap: [Day of Week], [Month Day, Year]

### Meetings
- List each meeting with time and title
- Note if user was organizer vs attendee (if available)
- If no meetings, say "No meetings scheduled"

### GitHub Activity
- Paste the GitHub sub-agent's formatted output directly
- If today is Monday, show weekend PRs in a separate "Weekend" subsection

### Slack Activity
- Paste the Slack sub-agent's formatted channel summaries directly

### Linear Activity
- Paste the Linear sub-agent's status-change output directly
- For each ticket, cross-reference the GitHub data and label it:
  - **Shipped** — moved to Done AND has a merged/created PR or commit that day
  - **Started (no code yet)** — moved to In Progress (or In Review with no completion) and has NO PR/commit that day
  - **Board-only** — status changed but no other signal in any source
- If the Linear sub-agent reported "Possible status changes (unconfirmed timing)", surface them under a brief caveat rather than asserting the date

### Inferring whether work actually started
When a ticket moved to **In Progress** with no PR/commit, decide whether it looks like a genuine start vs. a board tidy, and say which. Weigh these signals:
- **Domain/time correlation** — do Slack messages or meetings that day touch the same project/topic as the ticket? (e.g. ticket is in an "AI Quality" project and there were messages in an AI channel + an AI guild meeting → likely a real start)
- **No code yet** — absence of a PR/commit means it's most likely investigation/scoping, not implementation; say that explicitly
- **Standup mentions** — if a Geekbot/standup message names the ticket or its next-step work, that reinforces a real start; if the ticket is absent from the stated plan, lean toward "parked/board-only"
- State the read plainly (e.g. "Started PE-3469 as investigation, not implementation — no code yet") and, when relevant, flag it as the ticket to check on mid-week if it stays put

### TL;DR
- 3-4 bullet points summarizing the day's most significant accomplishments and activities
- Focus on outcomes and decisions, not raw activity counts
- Synthesize across all sources (e.g., "Shipped the timezone fix PR after discussing approach in #platform-eng", or "Kicked off PE-3469 — moved to In Progress, but looks like early scoping, no code yet")
- Keep each bullet to one sentence

### Quick Stats
| Category | Count |
|----------|-------|
| Meetings | N |
| PRs Created | N |
| PRs Merged | N |
| PRs Reviewed | N |
| Commits (non-bot) | N |
| Slack Channels Active | N |
| Tickets → In Progress | N |
| Tickets → Done | N |

---

## Notes

- If any data source returns errors or empty results, note it gracefully (e.g., "Could not retrieve Slack activity") rather than failing
- If the user asks "what did I do on [specific date]", use that date instead of calculating the previous workday
- Keep the tone conversational and useful — this is a standup prep tool
- **Linear scope caveat**: the Linear sub-agent only checks tickets **assigned to the user**. A status change on a ticket assigned to someone else won't appear. Mention this once if Linear results are shown, and offer to widen the search on request.
- **Linear timing caveat**: precise transition dates are only available for started/completed/canceled states. For other moves (Todo, In Review, Backlog, Triage), timing is inferred and should be presented as unconfirmed. Offer to read a specific ticket's activity history if the user wants certainty.
