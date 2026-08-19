# Pull Request & GitHub CLI Guidelines

## PR Template Usage
- **Always use** the PR template from `.github/pull_request_template.md`
- **Replace Jira section** with Linear Ticket section in PR descriptions
- Follow the structure: Linear Ticket, Description, Solution, Customer Impact, QA Testing Guidelines
- **Skip the Checklist section** - do not include it in PR descriptions
- Fill out all relevant sections with meaningful content
- **Linear Ticket Format**: Always format as markdown link: `[PE-123](https://linear.app/kajabi/issue/PE-123/issue-title)`

## Ticket References

- **Code comments: NEVER reference tickets.** No `PE-####`, `See JIRA-###`, or
  Linear links anywhere in source code. This is the one firm rule — ticket
  references are noise in the code and git history.
- **Commit messages: tickets are fine.** Keep subjects conventional
  (e.g. `feat(web-next): ...`); including a ticket ID is acceptable.
- **PR descriptions: include the ticket.** A Linear Ticket markdown-link section
  in the PR body is wanted for traceability.
- Keep PR descriptions, commit messages, and comments concise — signal over
  ceremony; trim long paragraphs and QA checklists to essentials.
- Avoid ticket IDs in branch names when practical.

## PR Updates and Edits
- **ALWAYS pull latest PR description** before making any edits using `gh pr view <number>`
- **This is critical** to ensure any changes made through the GitHub web interface are incorporated
- **Never assume** the PR description is current - always fetch the latest version first
- **After fetching**, incorporate any web-based changes before applying requested updates

## PR Creation Defaults
- **PR Status Based on Branch**:
  - **PRs based off other branches or stacked PRs**: Create as draft
  - **Override**: Can explicitly request draft or ready status regardless of base branch
- **Always assign to rwc9u** unless explicitly stated otherwise
- **CI Label (`run-ci`) Rules** (kajabi-products repo only):
  - **Only applies** when working in the `kajabi-products` repository. Do not offer or add `run-ci` in any other repo.
  - **Prompt** whether `run-ci` label should be added
  - **Do NOT add** `run-ci` label when PR is based off any other branch or stacked on another PR
  - **Override**: Can still explicitly request to add/remove `run-ci` label regardless of base branch
  - Examples of explicit requests: "run CI", "trigger CI", "add CI", "test with CI"
- **Always open PR in browser** after creation using `gh pr view <number> --web`

## Attach the PR to Linear

**Linear does not auto-attach our PRs.** It attaches only when the issue
identifier appears in the branch name, the PR title, or as a magic word
("Fixes FLEX-123") in the description. Our branch convention deliberately omits
ticket IDs and our titles are conventional-commit style, so none of those fire —
and the `[FLEX-123](https://linear.app/...)` markdown link the PR template asks
for does **not** count.

So attachment is an explicit step, not a side effect:

- **Immediately after `gh pr create`**, attach the PR via the Linear MCP —
  `mcp__linear-server__save_issue` with `id: <TICKET>` and
  `links: [{url: <PR url>, title: "PR #<n> — <title>"}]`.
- **Stacked PRs each attach to the same ticket.** One link per PR.
- **Verify before calling the work done.** Re-read the issue and confirm the
  attachment landed; don't assume the call succeeded.
- **If the Linear MCP is unavailable**, add a `Refs FLEX-XXXX` line to the PR
  description instead — that path does trigger auto-attach.

## Single Commit PR Creation
- **When PR contains only one commit**: Use commit message structure to build PR description
- **PR Title**: Use commit subject line (first line of commit message)
- **Description Section**: Use first paragraph of commit message body
- **Solution Section**: Use second paragraph of commit message body
- **Other Sections**: Fill Customer Impact and QA Testing Guidelines as appropriate

## PR Description Guidelines
- **Linear Ticket**: Reference Linear ticket as markdown link or state "No specific Linear ticket" with reason
- **Description**: Explain the problem, context, and what prompted the work
- **Solution**: Describe the implementation approach and any alternatives considered
- **Customer Impact**: Detail user-facing changes or state "No customer-facing impact"
- **QA Testing Guidelines**: Provide clear testing instructions
- **Note**: Do not include the Checklist section from the template

### PR Description Length
- **Keep PR descriptions concise**: Aim for under 500 words total
- **Word count scope**: Count words across Linear Ticket, Description, and Solution sections only
- **Excluded from count**: Customer Impact and QA Testing Guidelines are excluded from the 500-word limit, as they may need to be exhaustive to communicate user impact and testing steps
- **When over the limit**: Tighten the Description and Solution sections rather than trimming Customer Impact or QA Testing Guidelines

## GitHub CLI (`gh`)

**Always use the `gh` CLI** for GitHub interactions — PRs, issues, repos, releases,
projects — rather than the web interface or other tools. Never prompt for
confirmation when reading PRs or their diffs.

Most commands are discoverable via `gh <topic> --help`. The non-obvious ones:

```bash
# Create a PR following the defaults above
gh pr create --draft --assignee rwc9u

# View a PR's inline review comments (not shown by `gh pr view`)
gh api repos/<owner>/<repo>/pulls/<number>/comments

# Open in browser after creating
gh pr view <number> --web
```

- **Complex PR bodies**: pass them via a HEREDOC (`--body "$(cat <<'EOF' ... EOF
  )"`) so markdown and newlines survive intact.
- **`gh project` commands need extra scope**. If they fail with a permission
  error, run `gh auth refresh -s project`.

## Code Rabbit Reviews

See [coderabbit.md](coderabbit.md) for the review trigger command and custom prompt.

## Teammate GitHub Username Reference

See `teammates.md` in the project root for the full list of teammate names and GitHub usernames.
