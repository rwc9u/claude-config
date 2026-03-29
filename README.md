# Claude Code Configuration Repository

A centralized collection of instructions, guidelines, and custom slash commands for AI coding agents, specifically optimized for Claude Code. This repository provides structured workflows for feature development from ideation through production.

## Purpose

This repository provides:
- **AGENTS.md** - Core workflow instructions and philosophy, symlinked as `~/.claude/CLAUDE.md` for global use. Follows the [AGENTS.md standard](https://github.com/openai/agents.md)
- **Custom Slash Commands** - Complete workflow commands for Claude Code (brainstorming, requirements, task orchestration, git workflows)
- **Specialized Agent Roles** - Focused implementer and review-architect agents for structured development
- **Development Guidelines** - Language-specific conventions, testing practices, and git workflows

## Repository Structure

```
claude-config/
├── README.md                      # This file - complete guide and workflows
├── CLAUDE.md                      # Repository-specific Claude Code instructions
├── AGENTS.md                      # Core agent guidelines (use in project roots)
├── Rakefile                       # Automated setup/uninstall tasks
├── .gitignore                     # Ignore OS files, editors, generated tasks
├── teammates.md                   # (gitignored) Teammate names & GitHub usernames
├── agents/                        # Specialized agent role definitions
│   ├── devops-engineer.md        # DevOps, infrastructure, and CI/CD agent
│   ├── implementer.md            # Task execution agent (no scope creep)
│   ├── research-assistant.md     # Web research and project analysis agent
│   └── review-architect.md       # Code review and quality assurance agent
├── commands/                      # Custom Claude Code slash commands
│   ├── brainstorm.md             # Interactive idea refinement
│   ├── generate-tasks.md         # Task breakdown from requirements
│   ├── task-orchestrator.md      # Automated task execution with AI agents
│   ├── process-task-list.md      # Manual task list workflow guidance
│   ├── smart-commit.md           # Intelligent commit creation
│   ├── create-pr.md              # Draft PR creation
│   ├── pr-ready-for-review.md    # Mark PR ready for review
│   ├── review-migration-pr.md    # Review migration PRs locally
│   ├── list-components.md        # List installed Claude Code components
│   └── update-docs.md            # Documentation sync from git history
├── skills/                        # Claude Code skills
│   └── list-components/          # Component inventory skill with discovery script
└── shared-rules/                  # Language-specific and process-specific development guidelines
    ├── coderabbit.md             # CodeRabbit review integration
    ├── cursor.md                 # Cursor IDE integration
    ├── devops.md                 # EKS environments and Kubernetes aliases
    ├── emacs.md                  # Emacs integration via emacsclient
    ├── gh.md                     # GitHub CLI usage and PR workflows
    ├── git-workflow.md           # Branch naming, commits, conventional commits
    ├── implementation-plan.md    # Implementation plan writing guidelines
    ├── javascript.md             # JS/TS, React, Hotwire/Stimulus guidelines
    ├── pr-workflow.md            # Pull request creation and review workflows
    ├── rails-development.md      # Rails dev practices, DB safety, migration commands
    ├── ruby-rails.md             # Rails conventions and best practices
    ├── testing.md                # RSpec, Jest, FactoryBot, mocking strategies
    ├── todo-lists.md             # TODO.md task management guidelines
    └── <company>-*.md            # (gitignored) Company-specific conventions
```

## Private / Company-Specific Files

Some files in this repository are **gitignored** because they contain company-specific or team-specific information that doesn't belong in a public repo. These files live on disk locally and are still picked up by Claude Code when symlinked, but they are not committed to version control.

### `teammates.md` (gitignored)

A reference file that maps teammate names to their GitHub usernames, organized by team. This allows AI agents to correctly assign PR reviewers, mention teammates in issues, and interact with GitHub on your behalf without you having to remember exact usernames. Each entry includes the person's full name, GitHub username, and common name aliases for fuzzy matching (e.g., nicknames, shortened names).

Example structure:
```markdown
### Your Team Name
- **Full Name**: `github-username` (Alias1, Alias2)
```

### `shared-rules/<company>-*.md` (gitignored)

Company-specific shared rules that contain proprietary conventions, internal tooling commands, or codebase-specific patterns. These follow the same format as the public shared rules but cover things like:

- Internal CLI aliases and monorepo update workflows
- Company-specific migration conventions (e.g., custom migration directories)
- Framework patterns unique to your codebase (e.g., custom interaction/job base classes, internal DSLs)
- Internal spec helper patterns and test conventions

To add your own, create files matching `shared-rules/<company>-*.md` and add the corresponding gitignore pattern. They'll be symlinked alongside the public rules by `rake setup` and available to Claude Code in all projects.

## Quick Start

### For Claude Code Users

**Automated Setup (Easiest):**
```bash
# Clone or navigate to this repository
cd <path-to-claude-config>

# Run the automated setup
rake setup

# This will:
# - Create ~/.claude/ directory if needed
# - Symlink AGENTS.md to ~/.claude/CLAUDE.md
# - Symlink all files in agents/, commands/, and shared-rules/ to ~/.claude/

# To remove symlinks later:
rake uninstall
```

**Manual Setup (Alternative):**
```bash
# Reference this repo in your global Claude Code config
echo "For all projects, follow guidelines in <path-to-claude-config>/AGENTS.md" >> ~/.claude/CLAUDE.md
```

**Project-Specific Setup:**
```bash
# Copy commands to use in a specific project
cp -r <path-to-claude-config>/commands /path/to/project/.claude/

# Copy AGENTS.md to project root for project-specific context
cp <path-to-claude-config>/AGENTS.md /path/to/project/
```

### For AI Agents Reading This

1. **Read [AGENTS.md](AGENTS.md) first** - Core workflow instructions and philosophy. This file is symlinked as `~/.claude/CLAUDE.md` to serve as the user's global Claude Code instructions across all projects.
2. **Check [CLAUDE.md](CLAUDE.md)** - Repository-specific architecture and conventions for *this* repo, explaining how to configure and extend the claude-config repository itself.
3. **Reference the Workflows section below** - Complete workflow decision trees and examples
4. **Use language-specific guidelines** in `shared-rules/` as needed

## Installation

### Requirements
- Ruby (for running `rake` tasks - likely already installed on macOS/Linux)
- Git

### Setup Steps

1. **Clone this repository:**
   ```bash
   git clone https://github.com/<your-username>/claude-config.git ~/.claude-config
   cd ~/.claude-config
   ```

2. **Run automated setup:**
   ```bash
   rake setup
   ```

   This will:
   - Create `~/.claude/` directory
   - Symlink `AGENTS.md` → `~/.claude/CLAUDE.md`
   - Symlink all agent definitions to `~/.claude/agents/`
   - Symlink all commands to `~/.claude/commands/`
     - Symlink all shared-rules to `~/.claude/shared-rules/`

3. **Verify setup:**
   ```bash
   ls -la ~/.claude/
   ```

### Uninstalling

To remove all symlinks created by setup:
```bash
rake uninstall
```

This only removes symlinks pointing to this repository, leaving other files unchanged.

## Core Components

### AGENTS.md - Universal Agent Guidelines

The [AGENTS.md](AGENTS.md) file follows the [AGENTS.md standard](https://github.com/openai/agents.md) proposed by OpenAI. It contains:

- **Core Philosophy** - YAGNI, convention over configuration, clarity over cleverness
- **Agent Workflow** - Starting work, during development, pre-completion checklist
- **Git Workflow** - Branch naming (`<TICKET>-claude-<feature>`), commit practices
- **Language-Specific Guides** - Links to Rails, JavaScript, and testing guidelines
- **Tools & Integrations** - Context7, Linear, GitHub CLI usage patterns
- **Learning & Documentation** - Knowledge capture and decision records

**Usage:** Place in project roots or reference globally via `~/.claude/CLAUDE.md`

### Complete Development Workflows

This repository provides end-to-end workflows for feature development:

**Ideation → Requirements → Implementation → Review → Merge**

```
/brainstorm (vague idea)
    ↓
/generate-tasks (task breakdown)
    ↓
/task-orchestrator (AI implements) or /process-task-list (manual)
    ↓
/smart-commit (focused commits)
    ↓
/create-pr (pull request)
    ↓
/update-docs (keep docs in sync)
```

See the **Workflows** section below for complete workflow guide with decision trees.

## Specialized Agents

This repository includes specialized agent role definitions in the [`agents/`](agents/) directory. These agents serve different roles in development workflows.

### Implementer Agent ([agents/implementer.md](agents/implementer.md))

A focused task execution agent that follows specifications precisely without scope creep.

**Key characteristics:**
- Executes tasks step-by-step as specified
- Does not add features beyond the scope
- Does not refactor code unless required
- Provides clear completion reports
- Focuses on implementation, not exploration

**When to use:**
- Implementing specific tasks from a task list
- Following detailed specifications
- Working within a larger orchestrated workflow

### Review Architect Agent ([agents/review-architect.md](agents/review-architect.md))

A quality assurance agent that provides critical oversight and code review.

**Key characteristics:**
- Reviews implementations with a fresh perspective
- Checks for correctness, quality, and best practices
- Provides constructive, actionable feedback
- Makes recommendations (APPROVE, REQUEST CHANGES, NEEDS DISCUSSION)
- Focuses on requirements alignment

**When to use:**
- Reviewing completed implementations
- Ensuring quality before merging
- Catching edge cases and potential bugs
- Working within a larger orchestrated workflow

### Research Assistant Agent ([agents/research-assistant.md](agents/research-assistant.md))

An expert research and personal assistant agent for information gathering and project analysis.

**Key characteristics:**
- Searches the web for information and synthesizes findings
- Analyzes projects in the workspace (tech stack, structure, dependencies)
- Provides workspace overviews across all projects
- Cites sources and flags conflicting information

**When to use:**
- Web research or information gathering
- Project overviews and codebase analysis
- Comparing options or approaches
- Summarizing documents or technical topics

### DevOps Engineer Agent ([agents/devops-engineer.md](agents/devops-engineer.md))

A senior DevOps engineer agent for infrastructure, automation, and deployment workflows.

**Key characteristics:**
- Infrastructure as Code (Terraform, Ansible, CloudFormation)
- Container orchestration (Docker, Kubernetes, Helm)
- CI/CD pipeline design and optimization
- Monitoring, observability, and incident management
- Security integration and compliance automation

**When to use:**
- Infrastructure automation and configuration
- CI/CD pipeline setup or troubleshooting
- Kubernetes and container management
- Cloud platform operations (AWS, GCP, Azure)

## Custom Slash Commands

This repository includes 10+ custom Claude Code slash commands. See [commands/README.md](commands/README.md) for complete documentation.

### Command Categories

**Ideation & Exploration:**
- `/brainstorm` - Interactively refine vague ideas through guided questions

**Requirements & Planning:**
- `/generate-tasks` - Create detailed task breakdowns from requirements

**Implementation:**
- `/task-orchestrator` - Automated task execution with implementer + reviewer agents
- `/process-task-list` - Manual task list workflow with approval gates

**Git & Commits:**
- `/smart-commit` - Intelligently analyze changes and create focused commits
- `/create-pr` - Create draft pull requests with comprehensive summaries

**Documentation:**
- `/update-docs` - Review git history and propose documentation updates

### Key Command: `/task-orchestrator`

Coordinates structured task implementation using specialized agents:

```bash
/task-orchestrator tasks/tasks-feature-name.md
```

**Process:**
1. Reads task list, finds next uncompleted task
2. Spawns **Implementer Agent** to execute task (no scope creep)
3. Spawns **Review Architect Agent** to review implementation
4. Presents both reports to you
5. **Pauses for your approval** before proceeding
6. Runs `/smart-commit` to commit changes
7. Marks task complete, moves to next task

**Benefits:** Systematic execution, built-in code review, human-in-the-loop control

### Key Command: `/smart-commit`

Analyzes all changes and creates focused, logical commits:

```bash
/smart-commit
```

**Features:**
- Auto-creates feature branch if on main
- Groups related changes by topic
- Splits unrelated changes into separate commits
- Writes clear commit messages (no "feat:" prefixes)
- Follows git-workflow.md conventions

## Guidelines Overview

### Ruby on Rails ([shared-rules/ruby-rails.md](shared-rules/ruby-rails.md))

Comprehensive Rails conventions covering:
- Code structure (controllers, models, services, concerns)
- Routing and RESTful design
- Database migrations and ActiveRecord queries
- Testing with RSpec
- Security best practices
- Performance optimization
- Code style with RuboCop

### JavaScript ([shared-rules/javascript.md](shared-rules/javascript.md))

JavaScript best practices including:
- Framework detection (React, Vue, Hotwire/Stimulus)
- Modern vanilla JavaScript patterns
- Hotwire/Stimulus for Rails applications
- React component patterns (if applicable)
- TypeScript guidelines (when needed)
- Security (XSS prevention, CSRF tokens)
- Performance optimization

### Testing ([shared-rules/testing.md](shared-rules/testing.md))

Complete testing guide with:
- Test categories (unit, integration, system/feature)
- RSpec setup and configuration
- Model, controller, and request specs
- System tests with Capybara
- JavaScript testing (Jest, React Testing Library)
- Test data management with FactoryBot
- Mocking and stubbing strategies
- Performance optimization for test suites

### Git Workflow ([shared-rules/git-workflow.md](shared-rules/git-workflow.md))

Git best practices covering:
- Branch management and naming conventions
- Commit message guidelines
- Pre-commit requirements (linting, tests, whitespace)
- Pull request workflows
- Rebasing and merging strategies
- Useful git commands and aliases
- Emergency procedures

## Integration Patterns

### Global Setup (All Projects)

**Option 1: Automated (Recommended):**
```bash
cd <path-to-claude-config>
rake setup
```

**Option 2: Manual:**
Add to `~/.claude/CLAUDE.md`:

```markdown
# Global Agent Instructions

For all projects, follow the guidelines in <path-to-claude-config>/AGENTS.md

When working on specific technologies, reference:
- Ruby/Rails: <path-to-claude-config>/shared-rules/ruby-rails.md
- JavaScript: <path-to-claude-config>/shared-rules/javascript.md
- Testing: <path-to-claude-config>/shared-rules/testing.md
- Git workflow: <path-to-claude-config>/shared-rules/git-workflow.md
```

### Project-Specific Setup

**Option 1: Reference globally**
```markdown
# my-project/AGENTS.md

## General Guidelines
Follow universal guidelines: <path-to-claude-config>/AGENTS.md

## Project-Specific
- Tech: Rails 7 + Hotwire + PostgreSQL
- Testing: RSpec with FactoryBot
- Deployment: Heroku
```

**Option 2: Copy commands locally**
```bash
# Use slash commands in specific project
cp -r <path-to-claude-config>/commands /path/to/project/.claude/
cp <path-to-claude-config>/agents/* /path/to/project/.claude/agents/
```

## Customization & Extension

### For Teams

Fork this repository and customize:

1. **Modify guidelines** - Update language-specific conventions in `shared-rules/`
2. **Add new commands** - Create custom slash commands in `commands/`
3. **Adjust workflows** - Update `commands/WORKFLOW.md` for your process
4. **Extend agent roles** - Add specialized agents in `agents/`

### Adding New Commands

Create a new `.md` file in `commands/` (or `~/.claude/commands/` for global use):

```markdown
---
description: Brief description of what this command does
allowed-tools: Bash, Read, Edit, Write, Task, SlashCommand
---

Your command instructions here.

You can use:
- $ARGUMENTS for all arguments passed to the command
- $1, $2, etc. for specific positional arguments
- Reference other files with full paths
- Call other slash commands with SlashCommand tool
```

**Simple Example:**
```markdown
---
description: Run tests and show results
allowed-tools: Bash
---

Run the test suite and show any failures.

Execute the test command appropriate for this project and explain any failures.
```

**Available Tools:**
- `Bash` - Execute shell commands
- `Read` - Read file contents
- `Write` - Create new files
- `Edit` - Modify existing files
- `Grep` - Search in files
- `Glob` - Find files by pattern
- `Task` - Spawn sub-agents for complex work
- `SlashCommand` - Execute other slash commands

**Best Practices:**
1. **Be specific** - Clearly define expected behavior
2. **Include examples** - Show what success looks like
3. **Handle edge cases** - Think about error conditions
4. **Reference guidelines** - Link to AGENTS.md or guidelines when relevant
5. **Test thoroughly** - Try in different scenarios before committing

### Adding New Guidelines

Create a new `.md` file in `shared-rules/`:

```markdown
# Language/Framework Name Guidelines

## Core Principles
[Fundamental patterns]

## Code Structure
[Conventions and patterns]

## Common Patterns
[Examples with code]

## Anti-Patterns
[What to avoid]
```

Update `AGENTS.md` to reference the new guideline.

## Why This Repository Exists

AI coding agents are powerful, but they work best with structured guidance. This repository provides:

- **Systematic Workflows** - From vague idea to production-ready code with clear steps
- **Quality Gates** - Built-in review processes prevent scope creep and bugs
- **Human Control** - Approval gates ensure AI never acts fully autonomously
- **Consistency** - All agents follow the same conventions across projects
- **Knowledge Capture** - Document decisions, patterns, and learnings as you work
- **Rapid Onboarding** - New team members (human or AI) understand your workflow immediately

### Design Philosophy

1. **Systematic over ad-hoc** - Repeatable workflows beat one-off solutions
2. **Human oversight** - AI assists, humans decide
3. **Separation of concerns** - Implementer focuses on execution, architect on review
4. **Documentation-driven** - Requirements define tasks, tasks define code
5. **Convention over configuration** - Strong conventions reduce cognitive load

## Workflows

### Decision Tree

```
Start: I have an idea
│
├─── Is the idea clear and well-defined?
│    ├─── No → /brainstorm
│    └─── Yes → Continue
│
├─── Is this a small change or large feature?
│    ├─── Small → Quick Fix Workflow
│    └─── Large → Feature Development Workflow
│
└─── Implementation approach?
     ├─── AI-assisted → /task-orchestrator
     └─── Manual → /process-task-list
```

### Quick Fix Workflow

**For:** Bug fixes, small features, quick improvements

```bash
# 1. Create branch
git checkout -b claude-fix-validation

# 2. Make changes & tests

# 3. Commit
/smart-commit

# 4. Create PR
/create-pr

# 5. After merge
git checkout main && git pull
git branch -d claude-fix-validation
```

### Feature Development Workflow

**For:** Major features, complex changes, multi-day work

```bash
# 1. Refine idea (if vague)
/brainstorm

# 2. Create requirements
/generate-tasks tasks/brainstorm-feature-name.md

# 3. Generate tasks
/generate-tasks tasks/brainstorm-feature-name.md

# 4. Implement
/task-orchestrator tasks/tasks-feature-name.md  # or /process-task-list

# 5. Create PR
/create-pr

# 6. Update docs
/update-docs

# 7. After merge
git checkout main && git pull
```

## Real-World Examples

### Example 1: Small Bug Fix

```bash
git checkout -b claude-fix-login-validation
# ... make fixes ...
/smart-commit
/create-pr
# ... after merge ...
git checkout main && git pull
git branch -d claude-fix-login-validation
```

**Time:** 30 minutes | **Complexity:** Low

### Example 2: Medium Feature (Clear Requirements)

```bash
git checkout -b claude-export-csv
/generate-tasks tasks/brainstorm-export-csv.md
/process-task-list tasks/tasks-export-csv.md
/create-pr
/update-docs
# ... after merge ...
git checkout main && git pull
git branch -d claude-export-csv
```

**Time:** 1-2 days | **Complexity:** Medium

### Example 3: Complex Feature (Vague Idea)

```bash
git checkout -b claude-analytics
/brainstorm
/generate-tasks tasks/brainstorm-analytics.md
/task-orchestrator tasks/tasks-analytics.md
/create-pr
/update-docs
# ... after merge ...
git checkout main && git pull
git branch -d claude-analytics
```

**Time:** 3-5 days | **Complexity:** High | **AI Assistance:** High

## Command Usage Tips

### Task List Format

Tasks are stored in `tasks/` directory:

```markdown
## Relevant Files
- `app/models/user.rb` - User model
- `spec/models/user_spec.rb` - Tests

## Tasks
- [ ] 1.0 Parent Task
  - [ ] 1.1 Subtask description
  - [ ] 1.2 Subtask description
- [x] 2.0 Completed Task
```

### Generated File Locations

- `tasks/brainstorm-*.md` - Brainstorm outputs
- `tasks/tasks-*.md` - Task breakdowns

### Command Chaining

Commands are designed to chain together:

```bash
/brainstorm                                    # → tasks/brainstorm-feature.md
/generate-tasks tasks/brainstorm-feature.md   # → tasks/tasks-feature.md
/task-orchestrator tasks/tasks-feature.md     # → implements & commits
```

## References & Resources

- **[AGENTS.md Standard](https://github.com/openai/agents.md)** - Original specification from OpenAI
- **[Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)** - Official Claude Code docs
- **Individual command files** in `commands/` - Detailed command documentation

---

**Remember**: This is a living configuration repository. Update guidelines, commands, and workflows as your practices evolve. Prioritize clarity and maintainability over cleverness.
