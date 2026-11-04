---
name: inbox-triage
description: This skill should be used when the user asks to "go through my inbox", "triage my email", "clean up my gmail", "archive what I don't need to read", "classify my emails", "inbox zero", "archive read emails", or wants their Gmail inbox sorted into keep-unread vs mark-read-and-archive using the Gmail MCP.
---

# Gmail Inbox Triage

Sort the Gmail inbox into **keep** (leave in inbox, unread) and **archive** (mark read + remove from inbox), then report the keep list. Uses the claude.ai Gmail MCP (`mcp__claude_ai_Gmail__*`).

Archiving is reversible (mail stays in All Mail), so proceed without a confirmation prompt once asked. Never trash, spam-mark, add labels, or re-add `UNREAD`.

## Setup

Load the tools in one call:

```
ToolSearch select:mcp__claude_ai_Gmail__search_threads,mcp__claude_ai_Gmail__get_thread,mcp__claude_ai_Gmail__unlabel_thread
```

If the request includes a URL that is not a Gmail link, ignore it and mention that in the report — don't fetch it.

## Mechanics

- **Archive** = one `unlabel_thread` call with `labelIds: ["UNREAD", "INBOX"]`. For already-read threads, `["INBOX"]`.
- **Throughput**: issue 40–50 `unlabel_thread` calls in a single parallel block. Sequential calls take forever.
- **Listing**: `search_threads` with `pageSize: 50`, `view: THREAD_VIEW_SUMMARY` (sender + subject is enough for ~95% of mail). Only `get_thread` for an ambiguous human-sent thread.
- **No page tokens come back** after modifying threads. Re-query instead; archived threads drop out, so the next query returns fresh mail.
- **Kept threads keep reappearing at the top** of a re-query. Two ways past them:
  - Prefer **date windows** (`before:YYYY/MM/DD`) once the recent pile is done — kept mail clusters near the top and older windows are mostly archivable.
  - Use **targeted bulk queries** for whole categories: `category:promotions`, `from:infrastructure@kajabi.com subject:"[Kajabi/"`. These are ~100% archive.
- **Avoid broad subject exclusions** (`-subject:"Action required"`) to skip kept threads — they also hide unrelated, never-classified mail. If you use them, the verification pass below is mandatory.

## Classification

**When unsure, keep.** A stray newsletter in the inbox costs nothing; an archived vendor reply means a missed message.

Keep (unread, in inbox):
- Humans writing to the user directly or with a small CC (vendor CSMs, account reps, colleagues)
- Tickets that name the user (Jira/Linear)
- Security events on the user's own accounts: new sign-ins, OAuth apps added, GitHub app install/permission requests, protected-action alerts
- Spend alerts with a number in them (latest of each kind only; archive older duplicates)
- Infra notices with a future deadline: AWS "Action required" (EKS/Bedrock/ElastiCache/IAM), vendor maintenance windows, model deprecations — newest per account, archive superseded copies
- Open AWS support cases needing attention (latest message per case)
- Future-dated calendar invites/updates
- Personal recognition (Awardco etc.)

Archive (mark read + remove from inbox):
- Newsletters/digests: every.to, Substack, beehiiv, Last Week in AWS, Reddit, Canny, Manning, Datadog weekly digest
- Vendor marketing, webinars, conference/CFP invites, job-board mail, consumer promos (DoorDash, Marriott, airlines)
- Status pages and release notes (Okta status, incident.io, Okta release notes)
- Broadcasts to 10+ recipients: daily API-key summaries, invoices, team-wide announcements with past deadlines
- GitHub notifications sent to a shared list (infrastructure@) — GitHub has its own inbox
- Receipts, paystubs, FSA/benefits notices, order confirmations
- Calendar invites, accepts/declines, and cancellations for meetings already past
- "No action required" notices and deadlines that have passed

## Workflow

1. **Size it**: `in:inbox is:unread` with `THREAD_VIEW_IDS_ONLY` to get the estimate (estimates are rough; trust the final empty query, not the count).
2. **Recent first**: page through `in:inbox is:unread` newest-first, classify, archive in parallel batches. An interrupted run has still cleared the newest mail.
3. **Older backlog**: switch to `before:` date windows; most of it is archivable.
4. **Bulk categories**: sweep `category:promotions` and list-sent GitHub notifications.
5. **Verify**: run plain `in:inbox is:unread` (no exclusions) and page until every result is a thread you chose to keep. This catches mail hidden by exclusion queries or skipped date gaps.
6. **Read-but-in-inbox mail** is out of scope unless asked — mention the count and offer. If asked to archive read mail: `in:inbox is:read` with `THREAD_VIEW_METADATA_ONLY`, check `messageCount` (a multi-message thread can match while still holding an unread message — `get_thread` those), remove `INBOX` only, and repeat until the query is empty.

Give a one-line progress update every couple of batches ("~320 archived, 27 kept; working through mail older than Oct 13").

## Report

Lead with counts (archived, kept). Then the keep list grouped by why it was kept — needs a decision, security, infra deadlines, lower priority — one line each. Summarize archived mail by category; never enumerate it. Note anything you deliberately left alone (read mail, ignored links).
