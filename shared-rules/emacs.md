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

## macOS: `emacsclient` can't find the socket (TMPDIR)

On macOS, a GUI Emacs (`/Applications/Emacs.app`, launched via Finder/Dock)
creates its server socket under the **per-user Darwin temp dir**, not under
`/tmp`. That directory is what `getconf DARWIN_USER_TEMP_DIR` prints (e.g.
`/var/folders/tt/8763sqf95lvg3zr01p6dwwr00000gp/T/`), and the socket lives at:

```
$(getconf DARWIN_USER_TEMP_DIR)emacs$(id -u)/server
```

`emacsclient` finds the socket by looking under `$TMPDIR`. A normal interactive
terminal already has `TMPDIR` set to that same Darwin dir, so plain
`emacsclient …` just works. But **some shells run with a different/sandboxed
`TMPDIR`** (for example an agent or CI shell where `TMPDIR=/tmp/...`). In those
shells `emacsclient` looks in the wrong place and fails with:

```
emacsclient: can't find socket; have you started the server?
```

This is **not** a sign the server is down — it's the wrong `TMPDIR`. Fix by
prefixing the real Darwin temp dir:

```bash
# Works regardless of the shell's TMPDIR
TMPDIR="$(getconf DARWIN_USER_TEMP_DIR)" emacsclient -n +42 path/to/file.rb
```

Confirm the socket exists first when debugging:

```bash
ls -la "$(getconf DARWIN_USER_TEMP_DIR)emacs$(id -u)/server"
```

### Version match
Use the client bundled with the running app so versions match
(`emacsclient --version` should equal the app's Emacs version). For an
`emacs-plus-app` / emacsformacosx install:

```bash
/Applications/Emacs.app/Contents/MacOS/bin/emacsclient -n +42 path/to/file.rb
```

## Checking Emacs Server Availability
- Verify the server with (TMPDIR-safe): `TMPDIR="$(getconf DARWIN_USER_TEMP_DIR)" emacsclient -e '(+ 1 1)'`
- A `can't find socket` error on macOS usually means the wrong `TMPDIR` (see above), **not** a stopped server — retry with the `TMPDIR` prefix before concluding the server is down
- If the server is genuinely not running, inform the user and suggest `M-x server-start` in their Emacs, or running `emacs --daemon`
