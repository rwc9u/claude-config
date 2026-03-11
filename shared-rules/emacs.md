# Emacs Integration Guidelines

## Opening Files in Emacs
- **Always use `emacsclient -n`** to open files in the user's running Emacs instance
- **Pass multiple files at once** when reviewing PRs or related code changes
- **Never use `emacs` directly** — always use `emacsclient` to reuse the existing Emacs server

## Common Use Cases
- When asked to "open in Emacs" or "open files in Emacs"
- When reviewing PR changes and need to open all modified files
- When navigating to specific implementation files
- When opening files for code review or editing

## Key emacsclient Options
- `-n, --no-wait` - Don't wait for the server to return (DEFAULT — always use this)
- `-c, --create-frame` - Create a new frame instead of reusing the current one
- `-r, --reuse-frame` - Reuse the current frame if one exists, otherwise create a new one
- `+LINE[:COLUMN]` - Open file at specific line and optional column (prefix before filename)
- `-a EDITOR, --alternate-editor=EDITOR` - Fallback editor if server is not running

## Examples
```bash
# Good - Opens multiple files in existing Emacs
emacsclient -n app/models/user.rb spec/models/user_spec.rb app/controllers/users_controller.rb

# Good - Opens file at specific line
emacsclient -n +42 app/models/user.rb

# Good - Opens file at specific line and column
emacsclient -n +42:10 app/models/user.rb

# Good - Opens all modified files from a PR
emacsclient -n \
  app/components/admin/coaching/themeable_upgrade_alert_component.html.erb \
  app/components/admin/offers/themeable_upgrade_alert_component.html.erb \
  app/views/admin/coaching/groups/settings/edit.html.erb

# Bad - Opens files one by one
emacsclient -n app/models/user.rb
emacsclient -n spec/models/user_spec.rb

# Bad - Uses emacs directly instead of emacsclient
emacs app/models/user.rb
```

## PR Review Workflow
When reviewing GitHub PRs:
1. First check out the PR branch with `gh pr checkout <PR_NUMBER>`
2. Get the list of modified files from `gh pr diff <PR_NUMBER>`
3. Open all modified files at once with `emacsclient -n file1 file2 file3...`

## Checking Emacs Server Availability
- Use `emacsclient -e '(+ 1 1)'` to verify the Emacs server is running
- If the server is not running, inform the user and suggest starting Emacs or running `emacs --daemon`
