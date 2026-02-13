---
paths:
  - "**/*_spec.rb"
  - "spec/**/*.rb"
---

# RSpec Testing Guidelines

## RSpec Structure Rules

### No described_class
- **Always use explicit class references** with `let(:unit_class)`
```ruby
# ✅ Good
RSpec.describe SomeClass do
  subject { unit_class }
  let(:unit_class) { SomeClass }
end
```

### Test Data Naming
- **Use trailing integers** for property values: `let(:user1)`, `let(:name1)`
- **No trailing integers** for class references: `let(:unit_class)`

### Method Descriptions
- **Use dot-notation** for all methods: `.class_method`, `.instance_method`
- **Not hash notation**: avoid `#instance_method`

### Standard Spec Structure
1. Class-level subject and unit_class
2. Class-level test data
3. Class-level specs ("knows its ancestry", "knows its properties")
4. Class method specs (`.method_name`)
5. Instance-level specs with `describe "instance"`
6. Inner class specs

### Lazy vs Eager Evaluation
- **Prefer `let!`** over `let` + `before` blocks for non-lazy data

## RSpec Expectations Rules

### Explicit Expectations
- **Prefer explicit `.to eq()`** over shortcuts
```ruby
# ✅ Good
expect(result).to eq(nil)
expect(status).to eq(true)

# ❌ Bad
expect(result).to be_nil
expect(status).to be_true
```

### Exception: Type Checking
- **Use `.to be_a()`** for type checking
```ruby
expect(result).to be_a(User)
```

### Negation Syntax
- **Use `.to_not`** over `.not_to`
```ruby
expect(result).to_not eq(nil)
```

### Mocking Pattern
- **Arrange-Act-Assert** pattern with `allow`/`have_received`
```ruby
# ✅ Good
it "calls the external service" do
  # Arrange
  allow(external_service).to receive(:process).and_return(result1)

  # Act
  subject.perform

  # Assert
  expect(external_service).to have_received(:process).with(data1)
end
```

### Line Wrapping for Expectations
- **Break at `.to`** when line is too long
```ruby
expect(subject.some_long_method_name)
  .to eq(some_very_long_expected_value_that_would_exceed_limit)
```

## Feature Flag Testing Pattern

### Dual RSpec.describe Structure
When testing code with feature flags, use two separate `RSpec.describe` blocks:

```ruby
# Main describe block with feature ON (future default state)
RSpec.describe(
  SomeClass,
  activate_features: :feature_name
) do
  # All specs with feature enabled
end

# TODO: Remove when removing the :feature_name feature flag
RSpec.describe SomeClass do
  # Only specs affected by the feature flag
  # Do not duplicate unrelated specs
end
```

### Key Rules
- **Main block first**: Test with feature ON (future state) using `activate_features:`
- **Duplicate block at bottom**: Test with feature OFF (current state without flag)
- **TODO comment required**: Mark duplicated block for removal
- **Minimal duplication**: Only copy specs affected by the feature flag
- **Cleanup-ready**: When removing flag, delete entire duplicated block

## Integration Notes

### Auto-Apply Patterns
When writing specs, automatically apply:
1. RSpec structure organization
2. Explicit expectation syntax
3. Dot notation for method descriptions
4. Proper test data naming conventions
5. Arrange-Act-Assert pattern for mocking