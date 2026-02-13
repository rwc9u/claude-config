# Agent Guidelines for the `gh` (GitHub CLI) Utility

## Overview

The `gh` CLI is the official GitHub command-line tool used for all GitHub interactions in the Kajabi workflow. It replaces web interface interactions and provides consistent, scriptable access to GitHub features.

## Basic Principle

**ALWAYS use `gh` CLI** for all GitHub interactions instead of web interface or other tools. This includes:
- Pull request operations
- Issue operations  
- Repository operations
- Release operations
- Project management operations

## Pull Request Operations

### Creating Pull Requests
```bash
# Create draft PR with default labels and assignee
gh pr create --draft --assignee rwc9u

# View PR in browser after creation
gh pr view <number> --web
```

### PR Creation Defaults
- **Always create PRs as draft** unless explicitly requested otherwise
- **Always assign to rwc9u** unless explicitly stated otherwise
- **Always open PR in browser** after creation using `gh pr view <number> --web`

### Common PR Commands
```bash
# View PR details
gh pr view <number>

# View PR diff (no confirmation prompts)
gh pr diff <number>

# Check out PR branch locally
gh pr checkout <number>

# Approve PR
gh pr review <number> --approve

# Request changes
gh pr review <number> --request-changes -b "message"

# View PR comments
gh api repos/foo/bar/pulls/123/comments
```

## PR Template Usage

When creating PRs, always follow these template rules:
- **Use the PR template** from `.github/pull_request_template.md`
- **Replace Jira section** with Linear Ticket section
- **Skip the Checklist section** - do not include it
- **Linear Ticket Format**: `[COOL-123](https://linear.app/kajabi/issue/COOL-123/issue-title)`

### PR Description Structure
1. **Linear Ticket**: Reference as markdown link or state "No specific Linear ticket" with reason
2. **Description**: Explain the problem, context, and what prompted the work
3. **Solution**: Describe the implementation approach and alternatives considered
4. **Customer Impact**: Detail user-facing changes or state "No customer-facing impact"
5. **QA Testing Guidelines**: Provide clear testing instructions

### Single Commit PR Creation
When PR contains only one commit:
- **PR Title**: Use commit subject line (first line)
- **Description Section**: Use first paragraph of commit body
- **Solution Section**: Use second paragraph of commit body
- **Other Sections**: Fill Customer Impact and QA Testing Guidelines as appropriate

## Issue Operations
```bash
# Create issue
gh issue create

# View issue
gh issue view <number>

# List issues
gh issue list
```

## Project Operations

### Project Management Basics
GitHub Projects provide kanban-style boards for managing work. Use `gh project` commands for all project interactions.

**Note**: Project commands require the `project` scope. Check with `gh auth status` and add if missing:
```bash
gh auth refresh -s project
```

### Creating and Managing Projects
```bash
# Create a new project
gh project create --owner <owner> --title "<title>"

# View project details
gh project view <number> --owner <owner>

# View project in browser
gh project view <number> --owner <owner> --web

# Edit project settings
gh project edit <number> --owner <owner> --title "<new-title>" --description "<description>"

# Close a project
gh project close <number> --owner <owner>

# Delete a project (use with caution)
gh project delete <number> --owner <owner>
```

### Project Items Management
```bash
# Add issue or PR to project
gh project item-add <project-number> --owner <owner> --url <issue-or-pr-url>

# Create draft issue in project
gh project item-create <project-number> --owner <owner> --title "<title>" --body "<body>"

# List all items in project
gh project item-list <project-number> --owner <owner>

# Edit project item
gh project item-edit --project-id <project-id> --id <item-id> --field-id <field-id> --text "<value>"

# Archive project item
gh project item-archive <project-number> --owner <owner> --id <item-id>

# Delete item from project
gh project item-delete <project-number> --owner <owner> --id <item-id>
```

### Project Fields Management
```bash
# List project fields
gh project field-list <project-number> --owner <owner>

# Create custom field
gh project field-create <project-number> --owner <owner> --name "<field-name>" --data-type <TYPE>
# Data types: TEXT, SINGLE_SELECT, DATE, NUMBER

# Delete field
gh project field-delete <project-number> --owner <owner> --id <field-id>
```

### Project Linking
```bash
# Link project to repository
gh project link <project-number> --owner <owner> --repo <owner/repo>

# Link project to team
gh project link <project-number> --owner <owner> --team <team>

# Unlink project from repository
gh project unlink <project-number> --owner <owner> --repo <owner/repo>

# List all projects for an owner
gh project list --owner <owner>
```

### Project Templates
```bash
# Mark project as template
gh project mark-template <project-number> --owner <owner>

# Copy project from template
gh project copy <template-number> --source-owner <owner> --target-owner <owner> --title "<new-title>"
```

### Common Project Workflows

#### Setting Up a New Sprint Board
```bash
# Create project
gh project create --owner kajabi --title "Sprint 2024-Q1"

# Add custom fields
gh project field-create 1 --owner kajabi --name "Priority" --data-type SINGLE_SELECT
gh project field-create 1 --owner kajabi --name "Story Points" --data-type NUMBER
gh project field-create 1 --owner kajabi --name "Sprint" --data-type TEXT

# Link to repository
gh project link 1 --owner kajabi --repo kajabi/sage-app
```

#### Adding Issues to Project
```bash
# Add multiple issues to project
gh project item-add 1 --owner kajabi --url https://github.com/kajabi/sage-app/issues/123
gh project item-add 1 --owner kajabi --url https://github.com/kajabi/sage-app/issues/124
gh project item-add 1 --owner kajabi --url https://github.com/kajabi/sage-app/pull/125
```

## Repository Operations
```bash
# View repository info
gh repo view

# Clone repository
gh repo clone <owner/repo>
```

## Release Operations
```bash
# Create release
gh release create

# View release
gh release view
```

## Important Notes

1. **No confirmation prompts**: Never prompt for confirmation when reading PRs or diffs
2. **Consistent workflow**: Use gh CLI exclusively for GitHub operations
3. **PR body formatting**: Use HEREDOCs for complex PR descriptions to ensure proper formatting
4. **Always view in browser**: After creating PRs, always open in browser for user convenience
5. **Project scope required**: GitHub Project commands require the `project` scope. If project commands fail with permission errors, run `gh auth refresh -s project` to add the necessary scope

## Example PR Creation with Template

```bash
gh pr create --draft --assignee rwc9u \
  --title "fix(models): resolve user authentication issue" \
  --body "$(cat <<'EOF'
## Linear Ticket
[COOL-123](https://linear.app/kajabi/issue/COOL-123/fix-auth-bug)

## Description
Users were experiencing intermittent authentication failures when logging in during peak hours. This was discovered through customer support reports and monitoring alerts.

## Solution
Implemented connection pooling for the authentication service and added retry logic with exponential backoff. This approach was chosen over increasing server capacity as it addresses the root cause of connection exhaustion.

## Customer Impact
Users will no longer experience login failures during peak usage times.

## QA Testing Guidelines
1. Simulate high load conditions using the load testing script
2. Attempt multiple concurrent logins
3. Verify retry logic in authentication logs
EOF
)"
```