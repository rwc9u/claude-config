---
description: List all installed skills, commands, agents, hooks, plugins and their sources
allowed-tools: Bash, Read
---

You are generating a full inventory of all Claude Code components installed in this environment.

## Instructions

Run the list-components discovery script:

```bash
ruby ~/.claude/skills/list-components/scripts/list-components.rb
```

Present the output to the user. If the script fails, read and execute the script from the skill directory directly:

```bash
ruby ~/dev/claude-config/skills/list-components/scripts/list-components.rb
```

## Handling User Questions

If the user asks about a **specific component type** (e.g., "just show me skills"), run the full script but only present the relevant section.

If the user asks **where something comes from**, highlight the source attribution for that component.

If the user asks to **filter by source** (e.g., "show me everything from superpowers"), scan the output and group matching components together.
