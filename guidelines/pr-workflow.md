# Pull Request Guidelines

## PR Template Usage
- **Always use** the PR template from `.github/pull_request_template.md`
- **Replace Jira section** with Linear Ticket section in PR descriptions
- Follow the structure: Linear Ticket, Description, Solution, Customer Impact, QA Testing Guidelines
- **Skip the Checklist section** - do not include it in PR descriptions
- Fill out all relevant sections with meaningful content
- **Linear Ticket Format**: Always format as markdown link: `[COOL-123](https://linear.app/kajabi/issue/COOL-123/issue-title)`

## PR Updates and Edits
- **ALWAYS pull latest PR description** before making any edits using `gh pr view <number>`
- **This is critical** to ensure any changes made through the GitHub web interface are incorporated
- **Never assume** the PR description is current - always fetch the latest version first
- **After fetching**, incorporate any web-based changes before applying requested updates

## PR Creation Defaults
- **PR Status Based on Branch**:
  - **PRs based off `main`**: Create as ready for review (not draft)
  - **PRs based off other branches or stacked PRs**: Create as draft
  - **Override**: Can explicitly request draft or ready status regardless of base branch
- **Always assign to kellyredding** unless explicitly stated otherwise
- **Always add `knowpro` and `Dev QA` labels** unless explicitly stated not to
- Add any additional labels explicitly requested alongside `knowpro` and `Dev QA`
- **CI Label (`run-ci`) Rules**:
  - **Automatically add** `run-ci` label when PR is based off `main` branch
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
- **Use custom review prompt** from `~/dev/agent-config/guidelines/coderabbit.md` to reduce noise while preserving valuable feedback
- **When user asks** "have Code Rabbit review this" or similar, refer to `~/projects/kajabi/agent-guidelines/coderabbit.md` for the full custom prompt
- **See `~/dev/agent-config/guidelines/coderabbit.md`** for the complete custom review prompt and additional commands

## Teammate GitHub Username Reference

### Primary Reviewers - Knowledge Products Team
When assigning PRs or referencing teammates, use these GitHub usernames:
- **Andrew Dally**: `andrewdally` (Andrew, Dally)
- **Andrew McIntee**: `AndrwM` (Andrew M, McIntee)
- **Audrey Sperry**: `audreysperry` (Audrey, Sperry)
- **Jamie Wagner**: `nobodyiscertain` (Jamie, Wagner)
- **Joe Pickert**: `PickertJoe` (Joe, Pickert)
- **Julia Bazhukhina**: `JulaB` (Julia, Bazhukhina)
- **Kelly Redding**: `kellyredding` (Kelly, Redding)
- **Michelle Child**: `michellechild` (Michelle, Child)
- **Quinten Jason**: `QuintonJason` (Quinten, Quentin, Jason)
- **Steve Hull**: `sdhull` (Steve, Hull)

### Secondary Reviewers - Other Teams

#### Commerce Team
- **Angel Mendoza**: `admendoz25` (Angel, Mendoza)
- **Andrew Perez**: `aperez-kajabi` (Andrew P, Perez)
- **Collin Redding**: `jcredding` (Collin, Colin, Redding)
- **Daniel Moreto**: `kajabi-daniel` (Daniel, Moreto)
- **Darryl McCool**: `darryl-mccool` (Darryl, McCool)
- **Devin Uhrich**: `duhrich` (Devin, Uhrich)
- **Kevin Compton**: `klcompt` (Kevin, Compton)
- **Kevin Zeillmann**: `KZeillmann` (Kevin Z, Zeillmann)
- **Matt McGee**: `m-mcgee` (Matt, McGee)

#### Mobile Team
- **John Calvin**: `jdcalvin` (John, Calvin)
- **Patrick MacDowell**: `PGMacDesign2` (Patrick, MacDowell)

#### Production Engineering Team
- **Katie Borisov**: `ktsalz` (Katie, Borisov)
- **Ken Grimm**: `kenmgrimm` (Ken, Kenn, Grimm)
- **Paul Simpson**: `prsimp` (Paul, Simpson)
- **Rob Christie**: `rwc9u` (Rob, Christie)
