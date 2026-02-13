# Git & PR Workflow Guidelines

## Git Conventional Commits Rules

### Commit Format
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding/modifying tests
- `chore`: Maintenance tasks

### Scope Determination
- Automatic from file paths: `models`, `controllers`, `services`, `specs`, etc.
- Component-based for larger changes: `user-auth`, `payment-processing`

### Smart Description Generation
- **feat**: "add [functionality]"
- **fix**: "resolve [issue description]"
- **refactor**: "extract [component/method]"
- **test**: "add specs for [component]"

### Attribution Rules
- **Never include** Claude Code attribution or co-author information in commit messages
- **Keep commits personal** - all commits should appear as the developer's work without AI attribution

### Commit Body Structure
- **Always use two paragraphs** for commit message bodies
- **First paragraph**: Context and problem description - what problem we're solving and how it was discovered
- **Second paragraph**: Solution approach - what we did to solve it and why we chose that approach
- **Line Wrapping**: Wrap body paragraph lines at 80 characters
  - Insert line break before the word that would exceed 80 characters
  - Continue text on the next line without indentation
  - Exception: Long URLs or other non-breakable content can exceed 80 characters
  - This rule applies ONLY to body paragraphs, not the subject line
- **Writing Style**: Write like a human, not a robot. Keep descriptions high-level and provide context that helps other developers understand the "why" behind the change, not just technical implementation details. Avoid overly technical jargon or step-by-step code explanations.

## Branch Workflow

### Creating Branches with Remote Tracking
```bash
# Create a new branch and push to set up remote tracking
git checkout -b <branch-name>
git push -u origin <branch-name>
```

### Deleting Branches (Local and Remote)
```bash
# Delete local branch
git branch -d <branch-name>

# Delete remote branch
git push origin --delete <branch-name>

# Or do both in sequence
git branch -d <branch-name> && git push origin --delete <branch-name>
```

### Branch Naming Convention
- **Pattern**: `<initials>/<feature-nameNN-task-name>`
- **feature-name**: Short 2-3 word description of larger feature being worked on
- **NN**: Branch sequence number with zero-padding (01, 02, 03, etc.) for stacked PRs
- **task-name**: Short 2-3 word description of specific task/sub-task for this branch
- **Examples**: `rc/timezone-fix01-admin-dropdown`, `rc/user-auth02-oauth-integration`

## Quality Checks
- Ensure descriptions are in imperative mood
- Limit first line to 72 characters for commits
- Use consistent scope naming
- Avoid generic terms like "update" or "change"
- Follow the branch naming convention strictly
