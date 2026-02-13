# To-Do List Management Guidelines

## Overview

A single `TODO.md` file in the workspace root (`~/dev/TODO.md`) is used to track all tasks. This provides a simple, consolidated view of active work, backlog items, and completed task history.

## File Location
- **Single file**: `~/dev/TODO.md`
- Do NOT create separate daily files or split into multiple files

## File Structure

The TODO list has three sections, in this order:

1. **Today** - Active tasks for today or currently in progress
2. **Backlog** - Tasks to be done later (not urgent)
3. **Complete** - Completed tasks organized by date (newest first)

### Template
```markdown
# TODO

## Today

- [ ] Active task 1
- [ ] Active task 2

## Backlog

- [ ] Future task 1
- [ ] Future task 2

## Complete

### YYYY-MM-DD
- [x] Completed task 1
- [x] Completed task 2
```

## Task Format

Tasks use simple checkbox markdown:
- `- [ ]` for incomplete tasks
- `- [x]` for completed tasks
- Include relevant links (PRs, Linear tickets, docs) inline with the task

## Task Management Rules

1. **Active Tasks**: Keep tasks that need to be done today or are currently in progress in the "Today" section
2. **Completing Tasks**: When a task is marked complete, move it from "Today" to the "Complete" section under the current date (format: `### YYYY-MM-DD`)
3. **Backlog**: Use this section for tasks that are not urgent but should be tracked
4. **Do NOT use "This Week" category**: Remove or avoid creating a "This Week" section
5. **Preserve history**: Never delete completed items from the Complete section

## Common Operations

### When user says "show my to-do list"
- Read `~/dev/TODO.md` and display it

### When user says "add to my to-do list"
- Add the item to the "Today" section (unless they say backlog)

### When user says "mark X as done" or "check off X"
- Change `- [ ]` to `- [x]`
- Move the item from "Today" to "Complete" under today's date heading
- Create the date heading (`### YYYY-MM-DD`) if it doesn't exist yet

### When user says "move X to backlog"
- Move the item from "Today" to the "Backlog" section

### When user says "move X to today"
- Move the item from "Backlog" to the "Today" section
