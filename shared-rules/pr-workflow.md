# Pull Request Guidelines

## PR Template Usage
- **Always use** the PR template from `.github/pull_request_template.md`
- **Replace Jira section** with Linear Ticket section in PR descriptions
- Follow the structure: Linear Ticket, Description, Solution, Customer Impact, QA Testing Guidelines
- **Skip the Checklist section** - do not include it in PR descriptions
- Fill out all relevant sections with meaningful content
- **Linear Ticket Format**: Always format as markdown link: `[PE-123](https://linear.app/kajabi/issue/PE-123/issue-title)`

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
- **CI Label (`run-ci`) Rules**:
  - **Prompt** whether `run-ci` label should be added
  - **Do NOT add** `run-ci` label when PR is based off any other branch or stacked on another PR
  - **Override**: Can still explicitly request to add/remove `run-ci` label regardless of base branch
  - Examples of explicit requests: "run CI", "trigger CI", "add CI", "test with CI"
- **Always open PR in browser** after creation using `gh pr view <number> --web`

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

## GitHub CLI Integration
- **Always use `gh` CLI** for all GitHub interactions instead of web interface or other tools
- **Never prompt for confirmation** when reading PRs or their diffs with the `gh` command
- **Prefer managing GitHub PRs** with the `gh` command
- See `gh.md` for complete GitHub CLI usage guidelines

## Code Rabbit Reviews
- **Use custom review prompt** from `~/dev/agent-config/shared-rules/coderabbit.md` to reduce noise while preserving valuable feedback
- **When user asks** "have Code Rabbit review this" or similar, refer to `~/dev/agent-config/agent-shared-rules/coderabbit.md` for the full custom prompt
- **See `~/dev/agent-config/shared-rules/coderabbit.md`** for the complete custom review prompt and additional commands

## Teammate GitHub Username Reference

See `teammates.md` in the project root for the full list of teammate names and GitHub usernames.
