# Testing RBS Signatures

Verify your RBS type signatures are correct by writing Ruby test files that exercise the typed APIs and running Steep against them.

## Why Test Signatures?

RBS signatures can have subtle errors:
- Wrong argument types or order
- Missing optional parameters
- Incorrect return types
- Generic type mismatches

Writing test files that use your APIs catches these errors before they cause problems in real code.

## Test Directory Structure

Create a dedicated test directory for type checking:

```
my_gem/
├── lib/
│   └── my_gem.rb           # Your Ruby implementation
├── sig/
│   └── my_gem.rbs          # Your RBS signatures
├── test/
│   └── rbs/                # Type checking test files
│       ├── Gemfile
│       ├── Steepfile
│       └── lib/
│           └── my_gem_usage.rb  # Ruby files exercising the API
```

## Setup

### Gemfile

```ruby
# test/rbs/Gemfile
source "https://rubygems.org"

gem "steep"
```

### Steepfile

```ruby
# test/rbs/Steepfile
D = Steep::Diagnostic

target :test do
  # Check the test files
  check "lib"

  # Point to your gem's signatures
  signature "../../sig"

  # Add any stdlib dependencies your gem uses
  library "json", "time", "fileutils"

  configure_code_diagnostics(D::Ruby.strict)
end
```

## Writing Test Files

### Basic Pattern

Write Ruby code that exercises your gem's public API:

```ruby
# test/rbs/lib/my_gem_usage.rb

require "my_gem"

# Test basic instantiation
user = MyGem::User.new("Alice", "alice@example.com")

# Test attribute access - verifies attr_reader types
name = user.name      # Should be String
email = user.email    # Should be String?

# Test method calls with correct argument types
user.update(name: "Bob", email: "bob@example.com")

# Test return types
result = user.save    # Should be bool
id = user.id          # Should be Integer?

# Test collection methods
users = MyGem::User.all
users.each do |u|
  puts u.name         # Verifies User is yielded
end

# Test methods with blocks
filtered = users.select { |u| u.active? }
```

### Testing Edge Cases

```ruby
# Test optional parameters
user1 = MyGem::User.new("Alice")                    # Without optional
user2 = MyGem::User.new("Bob", "bob@example.com")   # With optional

# Test keyword arguments
config = MyGem::Config.new(
  timeout: 30,
  retries: 3,
  debug: true
)

# Test overloaded methods
result1 = parser.parse("string input")   # String overload
result2 = parser.parse(File.open("x"))   # IO overload

# Test generic types
container = MyGem::Container.new(42)
value = container.get  # Should infer Integer

# Test nil handling
if user = MyGem::User.find(123)
  user.name  # user is User here, not User?
end
```

### Testing from Documentation

Extract examples from your gem's documentation:

```ruby
# From README examples
client = MyGem::Client.new(api_key: ENV["API_KEY"])
response = client.get("/users")
response.each do |user|
  puts user["name"]
end

# From YARD docs
# @example
#   calculator = Calculator.new
#   calculator.add(1, 2)  #=> 3
calculator = MyGem::Calculator.new
sum = calculator.add(1, 2)
```

## Running Tests

```bash
cd test/rbs
bundle install
bundle exec steep check
```

### Expected Output

When signatures are correct:
```
# Type checking files:

..

No type error detected. 🫖
```

When signatures have errors:
```
lib/my_gem_usage.rb:10:15: [error] Cannot pass a value of type `::String` as an argument of type `::Integer`
│ Diagnostic ID: Ruby::ArgumentTypeMismatch
│
└ user.update(name: "Bob")
              ~~~~
```

## Common Issues Found by Testing

### Wrong Argument Types

```ruby
# Test file
user.process(123)  # ERROR if signature says String

# Fix the RBS
def process: (Integer data) -> void  # Was (String data)
```

### Missing Optional Parameter

```ruby
# Test file
User.new("Alice")  # ERROR if email is required

# Fix the RBS
def initialize: (String name, ?String? email) -> void  # Add ?
```

### Incorrect Return Type

```ruby
# Test file
count = list.size
count + 1  # ERROR if size returns String

# Fix the RBS
def size: () -> Integer  # Was -> String
```

### Generic Type Mismatch

```ruby
# Test file
box = Box.new("hello")
box.get.upcase  # ERROR if Box[T] doesn't preserve T

# Check the RBS generic declaration
class Box[T]
  def get: () -> T  # Not -> untyped
end
```

## Integration with CI

Add type checking to your CI pipeline:

```yaml
# .github/workflows/typecheck.yml
name: Type Check

on: [push, pull_request]

jobs:
  steep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true
          working-directory: test/rbs

      - name: Run Steep
        working-directory: test/rbs
        run: bundle exec steep check
```

## Tips

1. **Start with public APIs** - Test the methods users actually call
2. **Use real examples** - Pull from documentation, README, or actual usage
3. **Test edge cases** - Optional params, nil returns, empty collections
4. **Keep tests minimal** - Just enough to exercise the types, not full test coverage
5. **Update with signatures** - When you change RBS, update test files too
6. **Test generic types** - Ensure type parameters flow through correctly
