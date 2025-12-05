# Scaffolding RBS from Existing Code

Generate initial RBS signatures from Ruby code using `rbs prototype` and TypeProf.

To scaffold RBS for new files:

```bash
# Static analysis (fastest, but all types are untyped)
bundle exec rbs prototype rb lib/literal/new_file.rb

# TypeProf (infers actual types via abstract interpretation)
typeprof lib/literal/new_file.rb

# Runtime reflection (requires loading the code)
bundle exec rbs prototype runtime --require-relative ./lib/literal --autoload "Literal::NewClass"
```

TypeProf provides the best type inference but may fail on newer Ruby syntax.


## rbs prototype rb (Static Analysis)

Parses Ruby source files to generate signatures:

```bash
# Single file
bundle exec rbs prototype rb lib/my_class.rb

# Multiple files
bundle exec rbs prototype rb lib/**/*.rb > sig/generated.rbs
```

**Output:**
```rbs
class MyClass
  attr_reader name: untyped
  attr_accessor count: untyped

  def initialize: (untyped name) -> untyped
  def process: (untyped data) -> untyped
end
```

**Characteristics:**
- Static analysis (parses AST, doesn't execute)
- Recognizes `attr_reader`, `attr_accessor`
- Preserves method order
- All types are `untyped`
- Includes source comments

**Best for:** Initial scaffolding, understanding structure

## rbs prototype runtime (Reflection)

Uses Ruby reflection on loaded classes:

```bash
RUBYOPT="-Ilib" bundle exec rbs prototype runtime -r my_library MyClass
```

**Characteristics:**
- Uses `Class.methods`, `instance_methods`, etc.
- Catches dynamically generated methods (`define_method`)
- Methods sorted alphabetically
- Doesn't recognize `attr_reader` (shows as regular methods)
- All types are `untyped`

**Best for:** Metaprogramming-heavy code, ActiveRecord models

## TypeProf (Type Inference)

Infers types by analyzing execution flow:

### Setup

Create an entry point that exercises your APIs:

```ruby
# sig/profile_entry.rb
require "my_library"

obj = MyClass.new("test")
obj.process({ foo: 1 })
obj.transform([1, 2, 3])
```

### Run

```bash
bundle exec typeprof -Ilib sig/profile_entry.rb
```

**Output:**
```rbs
class MyClass
  @name: String
  attr_reader name: String
  def initialize: (String) -> nil
  def process: (Hash[Symbol, Integer]) -> untyped
end
```

**Characteristics:**
- Infers actual types from execution
- Recognizes instance variables
- Respects visibility
- Limited metaprogramming support

**Best for:** Getting real type information

## Comparison

| Feature | `prototype rb` | `prototype runtime` | TypeProf |
|---------|---------------|---------------------|----------|
| Execution | Static | Reflection | Interpreted |
| attr_reader | Yes | No | Yes |
| Method order | Original | Alphabetical | Original |
| Dynamic methods | No | Yes | Limited |
| Type inference | None | None | Good |
| Instance vars | No | No | Yes |

## Recommended Workflow

### 1. Generate Initial Scaffold

```bash
bundle exec rbs prototype rb lib/**/*.rb > sig/initial.rbs
```

### 2. Add TypeProf Types

```bash
bundle exec typeprof -Ilib sig/profile.rb > sig/typeprof.rbs
```

### 3. Handle Dynamic Classes

```bash
RUBYOPT="-Ilib" bundle exec rbs prototype runtime -r my_lib MyDynamicClass >> sig/runtime.rbs
```

### 4. Merge and Refine

Manually combine results:
- Replace `untyped` with actual types
- Fix inferred types that are too narrow/wide
- Add missing method signatures

### 5. Validate

```bash
bundle exec rbs validate
bundle exec steep check
```

## Mirror Directory Structure

Create one RBS file per Ruby file:

```bash
# Create sig/ structure matching lib/
find lib -name '*.rb' -print | while read file; do
  target="sig/${file#lib/}"
  target="${target%.rb}.rbs"
  mkdir -p "$(dirname "$target")"
  bundle exec rbs prototype rb "$file" > "$target"
done
```

## Data and Struct

For `Data.define` and `Struct.new`, use runtime prototype:

```ruby
# t.rb
class Measure < Data.define(:amount, :unit)
end
```

```bash
bundle exec rbs prototype runtime -R t.rb Measure
```

```rbs
class Measure < ::Data
  def self.new: (untyped amount, untyped unit) -> instance
              | (amount: untyped, unit: untyped) -> instance

  attr_reader amount: untyped
  attr_reader unit: untyped
end
```

Then manually add types:

```rbs
class Measure
  attr_reader amount: Integer
  attr_reader unit: String

  def initialize: (Integer, String) -> void
                | (amount: Integer, unit: String) -> void
end
```

## Tips

- Start with public APIs, work inward
- Use `untyped` liberally for gradual typing
- Focus on method signatures first
- Keep RBS files in `sig/` mirroring `lib/`
- Validate frequently with `rbs validate`
