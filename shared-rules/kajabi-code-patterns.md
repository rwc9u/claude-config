---
paths:
  - "**/*.rb"
---

# Kajabi Code Patterns

This file contains Kajabi-specific coding patterns and conventions used throughout the codebase. These patterns apply to interactions, jobs, models, and their corresponding specs.

## Interaction Patterns

### Running Interactions
- **Use `run_interaction!`** for interactions that should raise on errors
- **Use `run` only** when you need to handle errors explicitly
- **Never use** `.run` directly on the interaction class in production code

```ruby
# ✅ Good - raises on error
run_interaction!(
  Coaching::ThemeInstalls::Create,
  coaching_themeable: coaching_group,
)

# ✅ Good - when handling errors
outcome = run_interaction(
  SomeInteraction,
  param: value,
)
if outcome.errors.any?
  # handle errors
end

# ❌ Bad - don't use class method directly
Coaching::ThemeInstalls::Create.run(
  coaching_themeable: coaching_group,
)
```

### Composing Interactions
- **Use `compose_for`** within interactions to chain operations
- **Always provide a symbol name** for the composed result

```ruby
@created_coaching_group =
  compose_for(
    :created_coaching_group,
    Coaching::Groups::Create,
    coaching_group_program: coaching_group_program1,
    coaching_group: new_coaching_group1,
    latest_group: latest_group1,
  )
```

### Background Job Enqueueing
- **Use `perform_job_later`** helper from `KnowledgeProductsInteractionBehaviors`
- **Never use** `perform_later` directly on job classes

```ruby
# ✅ Good
after_interaction do
  perform_job_later(
    Coaching::Groups::ThemeCloneJob,
    source_theme_id: latest_group.active_theme.id,
    cloned_theme_id: cloned_theme.id,
  )
end

# ❌ Bad
Coaching::Groups::ThemeCloneJob.perform_later(
  source_theme_id: latest_group.active_theme.id,
  cloned_theme_id: cloned_theme.id,
)
```

## Job Patterns

### Job Structure
- **Always include** `KnowledgeProductsJobBehaviors` for product jobs
- **Use `input` declarations** instead of method parameters
- **Implement `on_perform`** method, not `perform`
- **Always include `logged_params`** with `site_id`

```ruby
class Coaching::Groups::ThemeCloneJob < ApplicationJob
  include KnowledgeProductsJobBehaviors

  queue_as :products_high

  input :source_theme_id
  input :cloned_theme_id

  def on_perform
    # Job implementation
  end

  def logged_params
    {
      site_id: site&.id,  # Always include site_id
      source_theme_id: source_theme_id,
      cloned_theme_id: cloned_theme_id,
      coaching_group_id: cloned_theme&.themeable_id,
    }
  end

  private

  def site
    cloned_theme&.themeable&.site
  end

  def source_theme
    @source_theme ||= Theme.find(source_theme_id)  # Use find to raise on missing
  end

  def cloned_theme
    @cloned_theme ||= Theme.find(cloned_theme_id)
  end
end
```

### Error Handling in Jobs
- **Use `log_progress`** with severity levels for errors
- **Always notify Honeybadger** for exceptions
- **Re-raise after handling** to maintain job retry behavior

```ruby
rescue => e
  Honeybadger.notify(e)
  log_progress(
    "ThemeCloneError",
    error_class: e.class.name,
    error_message: e.message,
    severity: :error,
  )
  cloned_theme.update!(status: Theme::STATUS_ERROR)
  raise
end
```

## ActiveRecord Patterns

### Finding Records
- **Use `find`** when you want exceptions for missing records
- **Use `find_by_id`** only when you'll handle nil results
- **Use `find_by`** for other attribute lookups that might return nil

```ruby
# ✅ Good - raises ActiveRecord::RecordNotFound if missing
def source_theme
  @source_theme ||= Theme.find(source_theme_id)
end

# ✅ Good - handles nil case
def optional_theme
  @optional_theme ||= Theme.find_by_id(theme_id)
  return unless @optional_theme
  # ... continue processing
end

# ❌ Bad - silently returns nil when you expect a record
def source_theme
  @source_theme ||= Theme.find_by_id(source_theme_id)
end
```

### Distributed Reads Pattern

#### When to Use distribute_reads
- **ONLY use for read-only queries** - never for writes, updates, or deletes
- **Use for any database reads** that don't require immediate consistency
- **Common use cases**:
  - Finding records for display
  - Checking if records exist
  - Loading associations for business logic
  - Background job queries that only read data
  - Counting records
  - Aggregation queries

#### When NOT to Use distribute_reads
- **Never use for write operations** (create, update, delete)
- **Don't use when immediate consistency is required** (e.g., right after a create/update in the same request)
- **Avoid for financial or critical data** that must be absolutely current

#### Syntax Preferences
- **Always use curly braces** `{ }` instead of `do...end`
- **Single-line format** when readable
- **Multi-line with proper indentation** for complex queries

```ruby
# ✅ Good - single line with curly braces
distribute_reads { themes.where(status: Theme::STATUS_PENDING).exists? }

# ✅ Good - multi-line with curly braces, proper indentation
pending_theme = 
  distribute_reads {
    created_coaching_group.themes.where(status: Theme::STATUS_PENDING).first
  }

# ✅ Good - in finder methods
def find_latest_group
  distribute_reads {
    coaching_groups.unarchived.latest.first
  }
end

# ❌ Bad - using do...end
distribute_reads do
  themes.where(status: Theme::STATUS_PENDING).exists?
end

# ❌ Bad - using for write operations
distribute_reads { theme.update!(status: "active") }  # NEVER do this
```

#### Common Patterns

```ruby
# Checking existence before operations
def should_show_theme_pending?
  return false unless created_coaching_group.present?
  return false unless $features.active?(:coaching_theming, site.account)

  distribute_reads {
    created_coaching_group.themes.where(status: Theme::STATUS_PENDING).exists?
  }
end

# Loading records for display/logic
def redirect_to_url
  if should_show_theme_pending?
    pending_theme =
      distribute_reads {
        created_coaching_group.themes.where(status: Theme::STATUS_PENDING).first
      }
    AdminRoutes.admin_theme_pending_path(pending_theme)
  else
    AdminRoutes.admin_coaching_group_sessions_index_path(created_coaching_group)
  end
end

# In background jobs
def source_coaching_group
  distribute_reads { source_theme&.themeable }
end
```

#### Testing with distribute_reads
- **Use real database records** instead of mocking
- **Fabricate actual records** to test distributed read queries
- **Don't stub queries** inside distribute_reads blocks

```ruby
# ✅ Good - real database record for testing
let!(:pending_theme1) do
  Fabricate(
    :theme,
    themeable: coaching_group1,
    status: Theme::STATUS_PENDING,
  )
end

it "redirects when theme is pending" do
  # The distribute_reads block will find the real record
  expect(subject.redirect_to_url).to eq(expected_path)
end

# ❌ Bad - mocking the distributed read
before do
  allow(coaching_group1).to receive_message_chain(:themes, :pending, :exists?).and_return(true)
end
```

### Scopes and Finders
- **Add scopes to models** for reusable queries
- **Create finder methods** on parent models for common lookups

```ruby
# In model
scope :latest, -> { order(created_at: :desc) }

# In parent model
def find_latest_group
  distribute_reads do
    coaching_groups.latest.first
  end
end
```

## Spec Helper Patterns

### RSpec Spec Structure and Organization
- **Use existing describe blocks** when adding new test contexts
- **Place contexts within instance blocks** for instance method testing
- **Avoid redundant subject definitions** when nesting contexts in instance blocks
- **Preserve existing spec structure** - don't create parallel describe blocks

```ruby
# ✅ Good - properly nested within existing structure
describe "StreamlinedCoaching" do
  describe "instance" do
    subject { streamlined_coaching_class.new(coaching_themeable: coaching_themeable1) }
    
    context "with custom coaching colors" do
      let(:coaching_themeable1) do
        Fabricate(:coaching_program, primary_color: "#FF5733")
      end
      
      # No need for redundant subject definition here
      describe "#to_h" do
        it "includes the custom colors" do
          # test implementation
        end
      end
    end
  end
end

# ❌ Bad - creating parallel structure
describe "StreamlinedCoaching" do
  describe "instance" do
    # existing tests
  end
end

describe "with custom coaching colors" do # Wrong - should be nested inside instance
  subject do # Redundant - already defined in parent
    streamlined_coaching_class.new(coaching_themeable: coaching_themeable1)
  end
end
```

### Test Coverage Balance
- **Focus on unit and integration tests** for core functionality
- **Avoid feature specs for simple workflows** unless they test complex user interactions
- **Remove overkill test scenarios** that don't add meaningful coverage

```ruby
# ✅ Good - focused test on essential behavior
context "with custom coaching colors" do
  it "applies custom colors over site theme colors" do
    expect(result["color_primary"]).to eq("#FF5733")
    expect(result["btn_background_color"]).to eq("#3498DB")
    expect(result["color_body"]).to eq("#C4C4C4") # Verify other properties preserved
  end
end

# ❌ Bad - overkill edge case testing
context "when coaching colors are blank" do
  context "when primary is empty string" do
    # Too granular
  end
  context "when primary is nil" do
    # Too granular
  end
end
```

### Assertion Consistency
- **Use the same assertion style** across related tests
- **Include preservation checks** when testing overrides
- **Verify side effects aren't broken** when changing behavior

```ruby
# ✅ Good - consistent assertions across similar tests
# StreamlinedCoaching test
expect(result["color_primary"]).to eq("#FF5733")
expect(result["btn_background_color"]).to eq("#3498DB") 
expect(result["color_body"]).to eq("#C4C4C4") # Preserved

# LegacyCoaching test - same pattern
expect(result["color_primary"]).to eq("#FF5733")
expect(result["btn_background_color"]).to eq("#3498DB")
expect(result["color_body"]).to eq("#C4C4C4") # Also check preservation
```

### Interaction Spec Helpers
- **Use dedicated helpers** for stubbing and expectations
- **Place allows in before blocks** at the appropriate level

```ruby
# For run_interaction!
before do
  allow_to_run_interaction(Coaching::ThemeInstalls::Create)
end

it "runs the interaction" do
  subject
  expect_to_have_run_interaction(
    Coaching::ThemeInstalls::Create,
    coaching_themeable: new_coaching_group1,
  )
end

# For compose_for
let!(:outcome1) do
  allow_to_compose(
    Coaching::Groups::Create,
    coaching_group_program: coaching_group_program1,
    coaching_group: new_coaching_group1,
    latest_group: latest_group1,
  ){ created_coaching_group1 }
end

it "composes the interaction" do
  subject
  expect_to_have_composed(
    Coaching::Groups::Create,
    coaching_group_program: coaching_group_program1,
    coaching_group: new_coaching_group1,
    latest_group: latest_group1,
  )
end
```

### Job Spec Helpers
- **Use job spec helpers** for background job testing

```ruby
before do
  allow_to_perform_later(Coaching::Groups::ThemeCloneJob)
end

it "enqueues the job" do
  subject
  expect_to_have_performed_later(
    Coaching::Groups::ThemeCloneJob,
    source_theme_id: latest_group_theme1.id,
    cloned_theme_id: cloned_theme.id,
  )
end
```

### Database Records in Specs
- **Use `let!`** for database records instead of stubbing finds
- **Avoid stubbing** `find_by_id` or `find` methods

```ruby
# ✅ Good - real database records
let!(:source_theme1) do
  Fabricate(:theme, status: Theme::STATUS_ACTIVE)
end
let!(:cloned_theme1) do
  Fabricate(:theme, status: Theme::STATUS_PENDING)
end

# ❌ Bad - stubbing finds
before do
  allow(Theme).to receive(:find_by_id).with(source_theme_id1)
    .and_return(source_theme1)
end
```

## Logging Patterns

### Always Log Site ID
- **Include `site_id`** in all logged_params
- **Find site through associations** when needed

```ruby
def logged_params
  {
    site_id: site&.id,  # Always first
    # ... other params
  }
end

private

def site
  # Navigate through associations to find site
  cloned_theme&.themeable&.site
end
```

### Progress Logging
- **Use `log_progress`** for significant events
- **Include severity** for errors and warnings

```ruby
log_progress("ThemeNotFound", severity: :error)
log_progress("ProcessingComplete", count: items.count)
```

## Implementation Plan Patterns

### Complete File Coverage
- **Include ALL affected files** in implementation plans
- **Show model changes** (scopes, finders) not just interactions
- **Include admin interactions** that consume main interactions
- **Show complete spec coverage** for all changes

### Keep Agent Guidelines
- **Preserve TODO comments** in code examples for agent guidance
- **Include lookup instructions** for patterns to research
- **Add comments about** where to place new code relative to existing code

### Spec Organization
- **Show where specs should be placed** relative to existing specs
- **Include both happy path and edge cases**
- **Show feature flag handling** with dual RSpec.describe blocks when needed