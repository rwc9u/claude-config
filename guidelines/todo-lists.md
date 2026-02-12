# To-Do List Management Guidelines

## Overview
Kelly uses dated to-do list files to track daily tasks and work items, plus an icebox list for items without a specific timeline. These files provide a persistent way to manage tasks across sessions and days.

## File Naming Convention
- **Daily Lists Pattern**: `todo-YYYY-MM-DD.md`
- **Icebox List**: `icebox.md`
- **Location**: `~/projects/kajabi/todo-lists/`
- **Examples**: 
  - `~/projects/kajabi/todo-lists/todo-2025-08-12.md`
  - `~/projects/kajabi/todo-lists/todo-2025-08-15.md`
  - `~/projects/kajabi/todo-lists/icebox.md`

## When to Use To-Do Lists
Automatically work with to-do list files when the user mentions:
- "Show me my to-do list"
- "Open today's to-do list"
- "Create a to-do list for tomorrow"
- "What's on my to-do list for [date]"
- "Add this to my to-do list"
- "Update my to-do list"
- "Check off items on my to-do list"
- Any language around managing, viewing, or working with dated to-do lists

## When to Use the Icebox List
The icebox list is for items without a specific timeline. Use it when the user mentions:
- "Add this to the icebox"
- "Put this in the icebox"
- "Move this to icebox"
- "What's in my icebox?"
- "Show me the icebox list"
- "I'll get to this eventually" (suggest adding to icebox)
- "Not sure when I'll do this" (suggest adding to icebox)
- "Save this for later" (suggest adding to icebox)
- "Move this out of today/tomorrow" (without new date, suggest icebox)
- "Pull this from the icebox"
- "Move from icebox to today/tomorrow"

## Icebox List Purpose
The icebox list (`~/projects/kajabi/todo-lists/icebox.md`) serves as:
- **Long-term storage** for tasks without immediate deadlines
- **Idea capture** for things to remember but not schedule yet
- **Backlog alternative** for personal items (vs project backlog tasks)
- **Parking lot** for deprioritized items from daily lists
- **Reference list** for "someday/maybe" tasks

## File Structure

### Daily To-Do Lists
```markdown
# To-Do List for [Month Day, Year]

## Tasks

### 1. [Task Title]
- **Details**: [Any relevant details, PR numbers, links, etc.]
- **Action**: [Specific action needed]
- **Status**: [ ] (unchecked) or [x] (completed)

### 2. [Task Title]
- **Details**: [Any relevant details]
- **Action**: [Specific action needed]
- **Status**: [ ]

## Notes
- Created: [Creation date]
- [Any additional notes or context]
```

### Icebox List Structure
```markdown
# Icebox List

## Items

### [Task Title]
- **Added**: [Date added to icebox]
- **Details**: [Any relevant context]
- **Action**: [What needs to be done]

### [Task Title]
- **Added**: [Date added to icebox]
- **Details**: [Any relevant context]
- **Action**: [What needs to be done]

## Notes
- Last reviewed: [Date]
- Total items: [Count]
```

## Common Operations

### Finding To-Do Lists
```bash
# List all to-do files
ls ~/projects/kajabi/todo-lists/todo-*.md

# Find today's to-do
ls ~/projects/kajabi/todo-lists/todo-$(date +"%Y-%m-%d").md

# Find tomorrow's to-do
ls ~/projects/kajabi/todo-lists/todo-$(date -v +1d +"%Y-%m-%d").md

# Find to-do for specific date
ls ~/projects/kajabi/todo-lists/todo-2025-08-12.md
```

### Reading To-Do Lists
- Always use the Read tool to display the current contents
- If no date is specified, assume "today"
- If file doesn't exist for requested date, inform the user

### Creating To-Do Lists
- Use Write tool with the standard file structure
- Include creation date in Notes section
- Format dates as "August 12, 2025" in the title

### Updating To-Do Lists
- Use Edit tool to mark items complete with [x]
- Add new items maintaining the numbered structure
- Preserve existing content when adding new items
- **DO NOT ask for permission** - directly update to-do lists when requested (Update tool is allowed)

### Managing the Icebox
- **Adding items**: Append new items with today's date in "Added" field
- **Moving to icebox**: Copy item from daily list, add to icebox, remove from daily list
- **Moving from icebox**: Copy item to target daily list, remove from icebox
- **Reviewing**: Update "Last reviewed" date when showing icebox contents
- **Count maintenance**: Update total count when adding/removing items

## Best Practices
1. **Always check if file exists** before trying to read
2. **Use consistent formatting** to maintain readability
3. **Include relevant links** (PRs, Linear tickets, etc.) in task details
4. **Date stamp creation** in the Notes section
5. **Preserve task history** - don't delete completed items, mark them with [x]

## Examples of User Requests

### Daily Lists
**User**: "What's on my to-do list?"
**Action**: Read `~/projects/kajabi/todo-lists/todo-[today's-date].md`

**User**: "Add fixing PR comments to tomorrow's to-do"
**Action**: Edit or create `~/projects/kajabi/todo-lists/todo-[tomorrow's-date].md`

**User**: "Check off the first item on today's list"
**Action**: Edit today's file, change `[ ]` to `[x]` for item 1

**User**: "Show me Monday's to-do list"
**Action**: Calculate Monday's date, read that file

### Icebox Operations
**User**: "Move item 3 to the icebox"
**Action**: Copy item 3 from today's list to icebox.md, remove from today

**User**: "Add 'research new framework' to icebox"
**Action**: Append new item to icebox.md with today's date

**User**: "What's in my icebox?"
**Action**: Read icebox.md, report count in summary

**User**: "Pull 'update documentation' from icebox to tomorrow"
**Action**: Copy item from icebox.md to tomorrow's list, remove from icebox

**User**: "I'll deal with this later"
**Action**: Suggest: "Would you like me to add this to your icebox list?"