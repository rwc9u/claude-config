# Testing Guidelines

Testing policy that applies to every project. Language-specific mechanics live in
[rspec-style.md](rspec-style.md) (RSpec, loads for spec files) and
[javascript.md](javascript.md) (JS, loads for JS/TS files).

## Core Policy

- **Always ship tests with implementation.** Every feature and every bug fix.
- **Never delete a failing test.** Fix the test or fix the code — removing it to
  make the suite pass is never acceptable.
- **Hit the real database.** Unit and integration tests should exercise real
  persistence, not stubbed-out finders.
- **Mock sparingly**, and only at the system boundary (see below).
- **Keep tests simple.** No branching logic, no loops over cases, no clever
  helpers. A test that needs explaining is a test that will be misread.
- **Fail loudly.** A broken test should say what broke, not just that something did.

## What to Run Locally

**Run only the specs covering the files you changed.** Not the whole suite, not
the whole engine, not the whole directory — the specs for the files in the diff,
plus any spec that directly exercises them.

CI is the safety net for everything else. Push the branch, open the PR, and let
the full suite report what a targeted run could not see; fix real breakage from
that signal. A green local run of thousands of unrelated examples buys very
little and costs minutes per iteration.

The same rule governs linting: lint the changed files, not the project. See
[git-workflow.md](git-workflow.md#listing-the-files-you-changed) for building
that file list correctly — and for why an empty list silently becomes "lint
everything."

**Reach for a wider local run only when there is a reason to expect wider
breakage** — a shared component, a model everything loads, a renamed public
method, a change to test infrastructure. Name the reason before paying for it.

## Test Categories

| Category | Scope | Database | Mocking |
|---|---|---|---|
| Unit | One model / service / utility | Yes | Boundaries only |
| Integration | Collaboration between components | Yes | Boundaries only |
| System / feature | End-to-end user workflow | Yes | Boundaries only |

- **Unit and integration tests carry the coverage.** They're fast and precise, so
  edge cases and error conditions belong here.
- **System tests cover the happy path only.** They are expensive and brittle;
  one scenario per workflow. Push edge cases down to unit tests.
- **Prefer request specs over controller specs** where the framework offers both.

## Mocking Boundaries

**Do mock** — things you don't own and can't run:

- Third-party APIs (Stripe, Twilio, S3, …)
- Payment processors
- Email and SMS delivery
- Time (freeze it rather than computing expected values from `now`)

**Do not mock** — things you own:

- Database operations and ActiveRecord associations
- Your own models, services, and interactions
- Plain Ruby/JS objects

Stubbing your own code couples the test to the implementation and stops it from
catching the bug you wrote the test for.

## Test Data

- **Prefer factories over fixtures** — more flexible, easier to read, better with
  associations.
- **Use real records for anything the code under test looks up.** Create the row;
  don't stub `find` / `find_by`.
- **Reach for the cheapest builder that still tests the thing**: `build_stubbed`
  (no DB) < `build` (no insert) < `create` (full insert). Only pay for what the
  assertion needs.
- **Share expensive setup** with `let_it_be` (test-prof) rather than recreating
  identical records per example.

## Performance

These apply to the full suite (CI, or a deliberately wide local run) — they are
not a reason to widen a local run. Default scope is still the changed files, per
[What to Run Locally](#what-to-run-locally).

- Precompile assets before a large feature-spec run so individual examples don't
  each pay compilation cost. Clobber first if JS or CSS changed.
- **In a git worktree, share the asset cache with the main checkout before the
  first spec run.** A fresh worktree compiles every asset from scratch the first
  time a spec renders a page — minutes, once per directory. Symlinking
  `tmp/cache/assets` to the main checkout's fixes it, and is safe because the
  cache is content-addressed: another branch's assets hash differently and miss
  rather than collide.
- Parallelize the suite rather than trimming coverage.
- Profile before optimizing — `test-prof` will tell you which factories dominate.
- A targeted run that takes minutes is a signal something is wrong with the
  invocation, not with the tests. Check what actually got collected.

## Coverage

- **Target 80%+ on critical paths.** 100% is not the goal and chasing it produces
  tests that assert nothing.
- Prioritize business logic, edge cases, and error conditions over glue code.

## Flaky Tests

Two causes account for nearly all flakiness:

- **Implicit ordering.** Never assert against an unordered collection — add an
  explicit `order` before comparing.
- **Real time.** Never compare a timestamp to `now`; freeze time, or assert
  within a tolerance window.

If a test fails intermittently, fix the cause. Retrying it hides a real race.
