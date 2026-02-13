---
name: list-components
description: This skill should be used when the user asks to "list all skills", "show my commands", "what plugins are installed", "where do my skills come from", "show all components", "list installed plugins", "what commands are available", "show skill sources", "inventory my setup", "list MCP servers", "show my agents", "what hooks are configured", "show LSP servers", or wants to understand what Claude Code extensions are installed and their provenance.
---

# List Claude Code Components

Discover and display all installed Claude Code components (plugins, skills, commands, agents, hooks, MCP servers, LSP servers) with source attribution showing where each component comes from.

## When to Use

Invoke this skill when the user wants to:
- See all installed skills, commands, agents, or plugins
- Understand where a specific skill or command originates
- Get an inventory of their Claude Code setup
- Distinguish between marketplace, symlinked, and locally installed components
- Audit what extensions are active in their environment

## How to Use

### Run the Discovery Script

Execute the bundled discovery script to generate a full component inventory:

```bash
ruby "${SKILL_DIR}/scripts/list-components.rb"
```

The script reads these registry files:
- `~/.claude/plugins/installed_plugins.json` - installed plugin registry
- `~/.claude/plugins/known_marketplaces.json` - marketplace source info
- Plugin cache directories for skills, commands, agents, hooks within each plugin
- `~/.claude/skills/` - standalone skills (checks for symlinks)
- `~/.claude/commands/` - user commands (checks for symlinks)
- `~/.claude/agents/` - user agents (checks for symlinks)
- `~/.claude/hooks/` - user hooks
- Plugin `plugin.json` and `.lsp.json` manifests for LSP servers and hooks configuration

### Present the Results

After running the script, present the output to the user in a readable format. Key information to highlight:

1. **Source types** - explain what each source means:
   - **github:org/repo** - installed from a GitHub marketplace repository
   - **local-directory:/path** - installed from a local directory marketplace
   - **symlink -> /path** - a symlink pointing to another location (e.g., a dev repo)
   - **local file** - a standalone file directly in the Claude config directory
   - **plugin (name@marketplace)** - bundled within an installed plugin

2. **Scope** - whether a plugin is user-wide or project-specific

3. **Summary counts** - the totals at the bottom give a quick overview

### Filtering

If the user asks about a specific component type (e.g., "just show me skills"), run the full script but present only the relevant section.

If the user asks about a specific component by name, search the output for that component and provide its details.

## Requirements

The discovery script requires Ruby (standard library only - `json`, `pathname`). No external gems needed.

## Source Type Reference

| Source Type | Meaning | Example |
|---|---|---|
| github:org/repo | GitHub marketplace plugin | github:anthropics/claude-plugins-official |
| local-directory:/path | Local filesystem marketplace | local-directory:/Users/rob/dev/my-marketplace |
| symlink -> /path | Symlink to another location | symlink -> /Users/rob/dev/claude-config/commands/commit.md |
| local file | Standalone file in ~/.claude/ | Directly created or copied command files |
| plugin (name@marketplace) | Bundled in an installed plugin | plugin (superpowers@claude-plugins-official) |
