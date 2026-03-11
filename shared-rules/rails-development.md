# Rails Development Practices

Practical development rules and safety guidelines for working in Rails projects.

## Ruby Version Management

Ruby versions are managed by **asdf** via `.tool-versions` files in each project. asdf automatically selects the correct Ruby version when you're in a project directory - no manual version switching is needed.

## Database Safety Rules

### CRITICAL DATABASE SAFETY
- **NEVER DROP OR RESEED THE DEVELOPMENT DATABASE**
- **FORBIDDEN COMMANDS**: Never run these commands on development:
  - `rake db:drop`
  - `rake db:reset`
  - `rake db:seed`
  - `rake db:setup`
  - `rails db:drop`
  - `rails db:reset`
  - `rails db:seed`
  - `rails db:setup`
  - Any command that would wipe or recreate the development database
- **DEVELOPMENT DATA IS PRECIOUS**: The development database contains specific, curated data that must be preserved
- **TEST DATABASE ONLY**: Database reset/reseed operations are ONLY allowed with `RAILS_ENV=test`
- **IF ASKED TO RESET**: Always refuse and explain that development database must be preserved

### Common Migration Command Examples
```bash
# Run pending migrations
rake db:migrate

# Check migration status
rake db:migrate:status

# Rollback last migration
rake db:rollback

# Rollback specific number of migrations
rake db:rollback STEP=3

# Migrate test database when out of sync
RAILS_ENV=test rake db:migrate

# Reset and reseed test database
RAILS_ENV=test rake db:reset

# Run specific migration version
rake db:migrate VERSION=20250425160000
```

## ActiveRecord Finder Patterns

### Finding Records
- **Use `find`** when you want exceptions for missing records
- **Use `find_by_id`** only when you'll handle nil results
- **Use `find_by`** for other attribute lookups that might return nil

```ruby
# Good - raises ActiveRecord::RecordNotFound if missing
def source_theme
  @source_theme ||= Theme.find(source_theme_id)
end

# Good - handles nil case
def optional_theme
  @optional_theme ||= Theme.find_by_id(theme_id)
  return unless @optional_theme
  # ... continue processing
end

# Bad - silently returns nil when you expect a record
def source_theme
  @source_theme ||= Theme.find_by_id(source_theme_id)
end
```

## RSpec Organization Guidelines

### Spec Structure and Organization
- **Use existing describe blocks** when adding new test contexts
- **Place contexts within instance blocks** for instance method testing
- **Avoid redundant subject definitions** when nesting contexts
- **Preserve existing spec structure** - don't create parallel describe blocks

```ruby
# Good - properly nested within existing structure
describe "SomeService" do
  describe "instance" do
    subject { described_class.new(param: value) }

    context "with custom options" do
      # No need for redundant subject definition here
      describe "#to_h" do
        it "includes the custom values" do
          # test implementation
        end
      end
    end
  end
end

# Bad - creating parallel structure outside existing blocks
describe "with custom options" do
  subject do # Redundant - already defined in parent
    described_class.new(param: value)
  end
end
```

### Test Coverage Balance
- **Focus on unit and integration tests** for core functionality
- **Avoid feature specs for simple workflows** unless they test complex user interactions
- **Remove overkill test scenarios** that don't add meaningful coverage

### Assertion Consistency
- **Use the same assertion style** across related tests
- **Include preservation checks** when testing overrides
- **Verify side effects aren't broken** when changing behavior

### Database Records in Specs
- **Use `let!`** for database records instead of stubbing finds
- **Avoid stubbing** `find_by_id` or `find` methods

```ruby
# Good - real database records
let!(:source_record) do
  create(:record, status: "active")
end

# Bad - stubbing finds
before do
  allow(Record).to receive(:find_by_id).with(id).and_return(record)
end
```
