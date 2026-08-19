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

- Precompile assets before a large feature-spec run so individual examples don't
  each pay compilation cost. Clobber first if JS or CSS changed.
- Parallelize the suite rather than trimming coverage.
- Profile before optimizing — `test-prof` will tell you which factories dominate.

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
