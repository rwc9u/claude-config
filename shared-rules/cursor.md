# Cursor Integration Guidelines

## Opening Files in Cursor
- **Always use the `cursor` CLI command** to open files in the user's IDE
- **Use the `-r` flag** to reuse the existing window: `cursor -r file1 file2 file3...`
- **Open all related files at once** when reviewing PRs or related code changes
- **Never use `-n` flag** unless specifically asked to open in a new window

## Common Use Cases
- When asked to "open in Cursor" or "open files in Cursor"
- When reviewing PR changes and need to open all modified files
- When navigating to specific implementation files
- When opening files for code review or editing

## Key Cursor CLI Options
- `-r, --reuse-window` - Force open files in already opened window (DEFAULT)
- `-n, --new-window` - Force open in new window (only when requested)
- `-g, --goto <file:line[:character]>` - Open file at specific line/column
- `-a, --add <folder>` - Add folder to last active window
- `-w, --wait` - Wait for files to be closed before returning

## Examples
```bash
# ✅ Good - Opens all PR files in existing window
cursor -r app/models/user.rb spec/models/user_spec.rb app/controllers/users_controller.rb

# ✅ Good - Opens file at specific line
cursor -r -g app/models/user.rb:42

# ✅ Good - Opens all modified files from a PR
cursor -r \
  app/components/admin/coaching/themeable_upgrade_alert_component.html.erb \
  app/components/admin/offers/themeable_upgrade_alert_component.html.erb \
  app/views/admin/coaching/groups/settings/edit.html.erb

# ❌ Bad - Opens in new window unnecessarily
cursor -n app/models/user.rb

# ❌ Bad - Opens files one by one
cursor -r app/models/user.rb
cursor -r spec/models/user_spec.rb
```

## PR Review Workflow
When reviewing GitHub PRs:
1. First check out the PR branch with `gh pr checkout <PR_NUMBER>`
2. Get the list of modified files from `gh pr diff <PR_NUMBER>`
3. Open all modified files at once with `cursor -r file1 file2 file3...`

## Checking Cursor Availability
- Use `cursor --help` to verify Cursor CLI is installed
- If Cursor CLI is not available, inform the user and provide file list instead