---
name: debug-ci-failure
description: This skill should be used when the user asks to "debug a CI failure", "why did this spec fail", "look at this CircleCI run", "check this CI build", "investigate this test failure", "this spec is flaky", "look at this pipeline", "CI is failing on my PR", "checks are red", shares a CircleCI URL or GitHub PR with failing checks, or wants to investigate a failing or flaky test using CircleCI and Datadog CI Test Visibility.
---

# Debug CI Failure

Investigate test failures and flaky specs by bridging CircleCI build data with Datadog CI Test Visibility. Start from a failing spec, CircleCI URL, or branch name, then progressively dig deeper through pipeline metadata, test event history, and trace-level detail.

## When to Use

- A spec is failing or flaky on CI
- The user shares a CircleCI pipeline, workflow, or job URL
- The user asks why a test failed or is intermittent
- The user wants to compare test durations across runs
- The user wants to inspect what happened inside a test run (HTTP calls, timing, errors)

## Prerequisites

This skill requires two MCP servers:

- **CircleCI MCP** (`circleci-mcp-server`) — for pipeline status, job details, test results, and failure logs
- **Datadog MCP** (`datadog-mcp`) — for CI test event search, duration analysis, and trace inspection

If either is unavailable, inform the user which MCP server is missing and what data you can't access.

## Investigation Flow

### Step 1: Identify the Starting Point

The user may provide any of these as a starting point:

| Input | What to do |
|-------|------------|
| GitHub PR number or URL | Use `gh` CLI to find failing CI checks and extract the CircleCI pipeline URL |
| Spec file path or name | Search for recent failures in Datadog |
| CircleCI URL (pipeline, workflow, or job) | Use CircleCI MCP to get details directly |
| Branch name | Use CircleCI MCP to get latest pipeline status for that branch |
| "It's flaky on main" | Search Datadog for the test on the main branch |

**Starting from a PR (most common path):**

Use the `gh` CLI to get CI check status and find the failing CircleCI run:

```bash
# Get all CI checks for a PR — shows status, name, and URL for each check
gh pr checks <PR_NUMBER>

# Example output:
# fail  feature_specs   https://app.circleci.com/pipelines/gh/Kajabi/kajabi-products/177005/workflows/.../jobs/974563
# pass  specs           https://app.circleci.com/pipelines/gh/Kajabi/kajabi-products/177005/workflows/.../jobs/974562
# pass  build_deps      https://app.circleci.com/pipelines/gh/Kajabi/kajabi-products/177005/workflows/.../jobs/974561

# You can also get the branch name from the PR
gh pr view <PR_NUMBER> --json headRefName --jq .headRefName
```

From the `gh pr checks` output, extract the CircleCI job URL for the failing check and use it with the CircleCI MCP in Step 2. The pipeline number is in the URL path (e.g., `177005` in the example above).

### Step 2: Get CI Build Context from CircleCI

Use the CircleCI MCP server to gather build-level information.

**Get pipeline status:**
```
mcp__circleci-mcp-server__get_latest_pipeline_status
  projectSlug: "gh/<org>/<repo>"
  branch: "<branch-name>"
```

**Get failure logs from a specific job:**
```
mcp__circleci-mcp-server__get_build_failure_logs
  projectURL: "<CircleCI job URL>"
```

**Get test results from a job:**
```
mcp__circleci-mcp-server__get_job_test_results
  projectURL: "<CircleCI job URL>"
  filterByTestsResult: "failure"
```

**Key data to extract from CircleCI:**
- Pipeline ID (UUID format like `807cb32f-0302-40f1-a09d-eeabadafc5a2`)
- Job name (e.g., `feature_specs`, `specs`)
- Branch name
- Commit SHA
- Whether the build passed, failed, or is still running

### Step 3: Bridge to Datadog with the Pipeline ID

The CircleCI pipeline ID is the key that connects CircleCI runs to Datadog CI Test Visibility. Use it to search for test events in Datadog.

**Search for all tests in a pipeline:**
```
mcp__datadog-mcp__search_datadog_test_events
  query: "@ci.pipeline.id:<pipeline-id>"
  sort: "-@duration"
```

**Search for a specific test in a pipeline:**
```
mcp__datadog-mcp__search_datadog_test_events
  query: "@ci.pipeline.id:<pipeline-id> @test.suite:*<spec_file_pattern>*"
  sort: "-@duration"
```

**Search for a specific test's history across recent runs:**
```
mcp__datadog-mcp__search_datadog_test_events
  query: "@test.name:\"<test name>\" @git.branch:main"
  from: "now-7d"
  sort: "-timestamp"
```

**Search for failures only:**
```
mcp__datadog-mcp__search_datadog_test_events
  query: "@ci.pipeline.id:<pipeline-id> @test.status:fail"
```

**Search for skipped tests (often indicates timeouts in ci-queue):**
```
mcp__datadog-mcp__search_datadog_test_events
  query: "@ci.pipeline.id:<pipeline-id> @test.status:skip @test.suite:*<pattern>*"
```

### Step 4: Analyze Test Event Data

Each test event from Datadog contains rich metadata. Key fields to examine:

| Field | What it tells you |
|-------|-------------------|
| `duration` | How long the test took (in nanoseconds) |
| `test.status` | pass, fail, or skip |
| `test.name` | The specific test/scenario name |
| `test.suite` | The spec file path |
| `ci_node_index` | Which CI parallel node ran it |
| `test_env_number` | Which parallel worker within the node |
| `error.message` | The failure message (if failed) |
| `error.stack` | Full stack trace (if failed) |

**Duration analysis patterns:**

- **Bimodal durations** (e.g., some runs ~5s, others ~240s): Indicates a race condition or intermittent blocking — the test either hits the fast path or gets stuck
- **Consistently slow**: Indicates a real performance problem in the test or the code it exercises
- **Gradually increasing over time**: Suggests growing data, added complexity, or resource contention

**ci-queue behavior:**
- ci-queue distributes specs across parallel workers with `--timeout 180` (configurable)
- A test that exceeds the timeout gets killed with SIGHUP and marked as `skip`
- The same test may be requeued to another worker (up to `--max-requeues`)
- So the same spec can appear multiple times in one pipeline — some passing, some skipped

### Step 5: Dig Deeper with Traces (When Available)

Datadog CI Test Visibility captures traces for test executions. These show the internal timing of HTTP requests, database queries, and other operations within a test run.

**Note:** CI test traces are in Datadog's CI Test Visibility product, not in APM. The `search_datadog_spans` and `get_datadog_trace` MCP tools search APM data and will NOT find CI test spans. Use `search_datadog_test_events` for CI test data.

To view the detailed trace flamegraph for a specific test run, direct the user to the Datadog CI Test Visibility UI. The test event data includes pipeline and job URLs that link back to both CircleCI and Datadog.

**What to look for in traces:**
- HTTP requests with long durations or errors (timeouts, 401s, 500s)
- The sequence of operations (what happened before the timeout)
- Whether the slow part is the test setup, the page load, or the assertion

### Step 6: Cross-Reference with Code Changes

Once you understand what's failing and how, check what changed:

```bash
# What changed in the spec file recently?
git log --oneline --since="4 weeks ago" -- <spec_file_path>

# What changed in the code the spec tests?
git log --oneline --since="4 weeks ago" -- <app_code_paths>

# What changed in test infrastructure?
git log --oneline --since="4 weeks ago" -- spec/support/ .circleci/
```

## Common Query Patterns

### "Is this spec flaky?"
```
query: "@test.name:\"<exact test name>\" @git.branch:main"
from: "now-7d"
sort: "-@duration"
page_limit: 10
```
Look for mixed pass/fail/skip statuses and variable durations.

### "What failed in this CI run?"
```
query: "@ci.pipeline.id:<pipeline-id> @test.status:(fail OR skip)"
sort: "-@duration"
page_limit: 10
```

### "How long does this spec normally take?"
```
query: "@test.name:\"<exact test name>\" @git.branch:main @test.status:pass"
from: "now-7d"
sort: "-@duration"
page_limit: 10
```

### "Did my branch fix the flakiness?"
Compare test durations between the main branch pipeline and your fix branch pipeline:
```
# Before (main)
query: "@ci.pipeline.id:<main-pipeline-id> @test.suite:*<pattern>*"

# After (fix branch)
query: "@ci.pipeline.id:<fix-pipeline-id> @test.suite:*<pattern>*"
```

## Tips

- **Pipeline IDs** are the bridge between CircleCI and Datadog — always extract and use them
- **`page_limit`** defaults to 5 and maxes at 10 for test events — keep it small since each event is large
- **Durations in Datadog** are in nanoseconds — divide by 1e9 for seconds
- **The `from` parameter** for Datadog queries uses relative time like `now-7d` or ISO 8601 format
- **Sort by `-@duration`** to find the slowest runs first — these are usually the interesting ones
- When a spec is flaky, look at **multiple runs of the same spec** within a single pipeline — ci-queue may run it on several workers, giving you fast vs slow comparisons in the same build
