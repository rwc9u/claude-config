---
paths:
  - "**/*.{rb,rake,erb}"
  - "Gemfile"
  - "Rakefile"
---

# Ruby Code Style Guidelines

## String Literals
- **Always use double-quotes** for string literals
```ruby
# ✅ Good
name = "John Doe"

# ❌ Bad  
name = 'John Doe'
```

## Trailing Commas
- **Use trailing commas** on all multiline structures
```ruby
# ✅ Good
user = {
  name: "John",
  email: "john@example.com",
}
```

## Line Length & Wrapping (use project's rubocop config)
- **Always check the project's rubocop `Layout/LineLength` max** before wrapping lines: `bundle exec rubocop --show-cops Layout/LineLength`
- **Do NOT default to 80 characters** — most projects use 120. Only break lines when they actually exceed the configured limit.
- **Avoid unnecessary string continuations** with `\` — these make code harder to read, especially with long method names like Rails path helpers
- **Assignment wrapping**: break after `=`
```ruby
some_variable =
  some_value_or_expression_that_causes_the_line_to_be_longer_than_80_characters
```

- **Method parameters**: wrap with parentheses and trailing commas
```ruby
some_method(
  arg1: arg1_value,
  arg2: arg2_value,
)
```

- **Method chaining**: leading dots with proper indentation
```ruby
some_variable =
  some_expression
    .some_chained_method
    .some_other_method
    .yet_another_chained_method_call
```

## Collection Methods
- **Prefer modern names**: `map`, `reduce`, `find`, `select`
- **Not**: `collect`, `inject`, `detect`, `find_all`

## Blocks
- **Semantic delimiters**:
  - `do...end` for procedural blocks (side effects)
  - `{...}` for functional blocks (return values)
  - Always `{...}` for one-liners

## Guard Clauses
- **Prefer guard statements** over nested conditionals
```ruby
# ✅ Good
def process_user(user)
  return unless user
  return unless user.active?
  return unless user.email.present?

  send_email(user)
end
```

## Ruby Class Structure Rules

### Class Organization Order (strict)
1. Include mixins (`include`, `extend`)
2. Define constants
3. Call DSL methods (Rails validations, scopes, etc.)
4. Define public class methods
5. Define private class methods
6. Define `initialize` method
7. Define public `attr_*` declarations
8. Define public instance methods
9. `private` declaration
10. Define private `attr_*` declarations
11. Define private instance methods
12. Inner classes/modules

### Naming Conventions
- **Use "Behaviors" suffix** for mixins: `TrackableBehaviors`
- **Flat structure** with `::` notation: `Project::View` not nested modules
- **Safe navigation** for delegation: `profile&.name`

## Integration Notes

### Auto-Apply Patterns
When Claude Code suggests changes, automatically apply:
1. String quote consistency (double-quotes)
2. Trailing comma addition
3. Line length corrections at 80 characters
4. Method chaining reformats with leading dots
5. Maintain Ruby class organization order
6. Apply semantic block delimiters consistently

### Quality Checks
- Ensure consistent scope naming
- Avoid generic terms like "update" or "change"
- Maintain Ruby class organization order
- Apply semantic block delimiters consistently