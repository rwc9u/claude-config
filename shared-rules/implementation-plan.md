# Implementation Plan Writing Guidelines

## Plan File Organization
- **Always save implementation plans** in the `~/dev/notes/implementation-plans/` directory
- **Never save plans** in the root of the project directory

## Plan File Naming Convention
- **Use structured naming format**: `YYYY-MM-DD_NN_PLAN-NAME.md`
  - `YYYY-MM-DD`: Current date (e.g., 2025-01-25)
  - `NN`: Two-digit sequence number for plans created on the same day (01, 02, 03...)
  - `PLAN-NAME`: Descriptive name using hyphens between words (no need for "-implementation" suffix)
- **Examples**: 
  - `2025-01-25_01_live-session-feature.md`
  - `2025-01-25_02_live-session-thumbnail.md`

### Sequence Number Determination Process
**IMPORTANT**: Before saving any implementation plan, you MUST determine the correct sequence number by:
1. **List all existing files** in the `~/dev/notes/implementation-plans/` directory using the `ls` command
2. **Filter files** that start with the current date prefix (YYYY-MM-DD format)
3. **Extract sequence numbers** from matching files (the NN part after the underscore)
4. **Determine next number**: If no files exist for the current date, use `01`. Otherwise, increment the highest found sequence number by 1
5. **Format with zero-padding**: Always use two digits (01, 02, 03, ..., 09, 10, 11, ...)

**Example workflow**:
```bash
# Step 1: List existing files
ls ~/dev/notes/implementation-plans/

# Step 2: If you see files like:
# 2025-08-05_01_user-auth.md
# 2025-08-05_02_payment-gateway.md
# 2025-08-04_01_api-endpoints.md

# Step 3: For date 2025-08-05, the highest sequence is 02
# Step 4: Next file should use sequence number 03
# Step 5: New file name: 2025-08-05_03_new-feature.md
```

## Plan Content Structure
- **Include detailed implementation steps** with file paths and code snippets
- **Provide background context** explaining the current state and approach, when that context is not already obvious from the overview
- **Add comprehensive spec examples** following Kajabi testing patterns
- **Add testing instructions** and configuration notes
- **Use markdown formatting** for clarity and organization
- **Always end files with a trailing newline** for better terminal readability when using `cat`

### File Writing Requirements
**CRITICAL**: When using the Write tool to create implementation plans:
1. **The content parameter MUST end with a newline character**
2. **Add `\n` at the very end of your content string**
3. **Example**: If your content ends with "...implementation provides", your Write tool content should end with "...implementation provides\n"
4. **Verification**: After writing, you can verify with: `tail -c 1 filename | od -An -tx1` (should show `0a`)

## Standard Plan Template

Only **Overview**, **Implementation Approach**, and **Detailed Implementation
Steps** are required. Every other section is optional: include it when it carries
information the implementer needs, and omit it entirely when it does not. Do not
keep a heading and fill it with restated content — an omitted section reads
better than a padded one.

```markdown
# Implementation Plan: [Feature Name]

## Overview
Brief description of what this plan accomplishes

## Background (optional — omit when Overview already covers it)
- Current state of the system
- Problem being solved
- Why this approach was chosen

Worth including when the current state is non-obvious, when a previous attempt
failed, or when the chosen approach beat a real alternative. Skip it for
straightforward work.

## Implementation Approach
High-level description of the solution

## Detailed Implementation Steps

### 1. [First Major Step]
**File**: `path/to/file.rb`

- Specific changes to make
- Code snippets with implementation

```ruby
# Implementation code
```

**Spec File**: `spec/path/to/file_spec.rb`

- Include unit test examples for the changes
- Research existing spec structure first
- Nest new contexts within existing describe blocks

```ruby
# Spec examples following Kajabi patterns
```

### 2. [Second Major Step]
Continue with all steps...

## Configuration Notes
- Any configuration changes needed
- Environment variables
- Dependencies

## Testing Instructions
1. How to test the implementation
2. Expected behavior
3. Edge cases to verify

## Benefits (optional — usually omit)
- List of benefits this implementation provides
```

The Benefits section is filler in most plans: if the Overview stated the problem,
the benefit is already implied. Include it only when the payoff is genuinely
non-obvious from the rest of the plan, or when the plan needs to justify itself
to someone who was not part of the decision.

## Spec Inclusion Guidelines

### What Specs to Include in Plans
- **Include unit tests** for all new methods and behaviors
- **Include integration tests** only for complex interactions between components
- **Avoid feature specs** unless testing critical user workflows
- **Keep spec examples focused** - avoid overly complex edge case scenarios

### Spec Writing Guidelines
- **Research existing spec structure** before adding new specs
- **Place specs in existing describe blocks** where they logically belong
- **Don't duplicate subject definitions** that already exist in parent blocks
- **Maintain consistency** with existing spec patterns and assertion styles
- **Include preservation checks** when testing overrides (verify unrelated properties remain intact)

### Spec Completeness Checklist
When writing implementation plan specs:
1. ✅ Unit tests for new model methods
2. ✅ Unit tests for new controller actions  
3. ✅ Unit tests for new serializer attributes
4. ✅ JavaScript component tests for React/frontend changes
5. ⚠️ Integration tests only for complex multi-component interactions
6. ❌ Feature specs only when absolutely necessary for critical user paths

## When to Create Implementation Plans
- Complex features requiring multiple file changes
- Features that other developers or AI agents will implement
- Work that needs to be documented for future reference
- Tasks being handed off between team members or sessions
