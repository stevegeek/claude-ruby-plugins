# Type Tracer for RBS Development

The `type_tracer.rb` script instruments Ruby code at runtime to capture actual types flowing through methods. This helps inform RBS signature development by showing concrete types observed during execution.

## Location

```
scripts/type_tracer.rb
```

## Usage

### CLI

```bash
# Trace by class/module name pattern
ruby scripts/type_tracer.rb -c 'MyApp::' test/my_test.rb

# Trace by file path pattern
ruby scripts/type_tracer.rb -p 'lib/my_app' test/my_test.rb

# Output as JSON for programmatic use
ruby scripts/type_tracer.rb -c 'User' -f json test/my_test.rb > types.json

# Show help
ruby scripts/type_tracer.rb --help
```

### Programmatic

```ruby
require_relative "scripts/type_tracer"

tracer = TypeTracer.new(class_pattern: /MyApp/)
tracer.trace do
  # Run code that exercises the methods you want to type
  run_tests
end

# Get structured output
puts tracer.to_json

# Or human-readable report
tracer.report
```

## Output Format

### Text Report

```
# Type observations from runtime tracing
# Format: Class#method(arg_types) -> return_types

MyApp::User#initialize(name: String, email: String) -> nil
MyApp::User#find(id: Integer) -> String?
MyApp::User.create(attrs: Hash[Symbol, String | Integer]) -> MyApp::User
```

### JSON Output

```json
{
  "MyApp::User#find": {
    "args": [["id: Integer"]],
    "returns": ["String", "nil"],
    "returns_nil": true,
    "exceptions": []
  }
}
```

## Interpreting Tracer Output

The tracer captures **concrete runtime types**. When writing RBS signatures, consider:

### 1. Generics

If a method returns different types depending on input, consider if it should be generic:

```
# Tracer output:
Container#get() -> String
Container#get() -> Integer

# Consider: Is Container generic?
# RBS: class Container[T]
#        def get: () -> T
#      end
```

### 2. Optional Types

The `returns_nil: true` flag indicates the method can return nil:

```json
{"returns": ["String", "nil"], "returns_nil": true}
```

Use optional type syntax:

```rbs
def find: (Integer) -> String?
```

### 3. Union vs Supertype

When tracer shows multiple types, decide if you want:
- **Union**: `String | Integer` (exact types)
- **Supertype**: `Numeric` (if Integer and Float observed)
- **Interface**: `_ToS` (if types share behavior)

```
# Tracer output:
process(value: Integer) -> ...
process(value: Float) -> ...

# Options:
def process: (Integer | Float) -> ...  # Union
def process: (Numeric) -> ...          # Supertype
def process: (_Numeric) -> ...         # Interface
```

### 4. Collection Element Types

Tracer detects collection element types:

```
Array[String | Integer]  # Mixed array
Hash[Symbol, String]     # Typed hash
Set[Integer]             # Typed set
```

Consider if this should be:
- Exactly as traced
- A generic parameter
- A type alias

### 5. Empty Collections

Empty collections appear as `Array[untyped]`. Check the code context to determine the intended element type.

### 6. Exceptions

The `exceptions` field shows what errors a method can raise:

```json
{"exceptions": ["ArgumentError", "KeyError"]}
```

This informs documentation but isn't part of RBS signatures.

## Workflow: Using Tracer to Write RBS

### Step 1: Identify Target Code

```bash
# Find the file to type
ls lib/my_app/user.rb
```

### Step 2: Find or Write Tests

Look for existing tests that exercise the code:

```bash
ls test/**/user*_test.rb
ls spec/**/user*_spec.rb
```

If no tests exist, write a small script that exercises the public API.

### Step 3: Run Tracer

```bash
ruby scripts/type_tracer.rb -c 'MyApp::User' -f json test/user_test.rb > user_types.json
```

### Step 4: Review Output

```bash
cat user_types.json | jq .
```

### Step 5: Generate Scaffold (Optional)

Use RBS tools for initial structure:

```bash
bundle exec rbs prototype rb lib/my_app/user.rb > sig/my_app/user.rbs
```

### Step 6: Enhance Types

Replace `untyped` with observed types, applying judgment:
- Use generics where appropriate
- Choose supertypes/interfaces over unions when sensible
- Add optional markers for nilable returns

### Step 7: Validate

```bash
bundle exec rbs validate
bundle exec steep check
```

## Limitations

1. **Only traces executed code paths** - Methods not called during tracing won't appear
2. **Shows concrete types** - Cannot infer generic intent; requires human judgment
3. **No block type inference** - Block parameter/return types must be determined from code inspection
4. **Dynamic methods** - `method_missing`, `define_method` may not trace accurately

## Tips

- Run tracer against comprehensive test suites for best coverage
- Cross-reference tracer output with actual code to understand intent
- Use multiple test runs to capture edge cases (nil returns, exceptions)
- Combine with `rbs prototype` for structure, tracer for type details
