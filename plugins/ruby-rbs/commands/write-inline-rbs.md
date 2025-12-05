---
description: Write inline RBS type annotations in Ruby source files using rbs-inline comment syntax.
argument-hint: <file_path> - Path to Ruby file or directory to add inline types
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Skill
---

# Write Inline RBS Annotations

You are adding inline RBS type annotations directly in Ruby source files using comment syntax.

## Process

### 1. Load the RBS Skill

First, load the RBS skill for comprehensive type knowledge:

```
Use the Skill tool to load: ruby-inline-rbs
```

Then read the inline RBS subskill for syntax details:
- `subskills/inline/SKILL.md`

### 2. Analyze Target

Read the Ruby file(s) specified by the user:
- Understand class/module structure
- Note method signatures, parameters, return patterns
- Identify instance variables
- Look for DSL usage (attr_*, delegate, etc.)

### 3. Find Tests

Search for related test files:
```
Glob for: test/**/*{target_name}*_test.rb, spec/**/*{target_name}*_spec.rb
```

Read tests to understand:
- Expected method behavior
- Edge cases (nil returns, exceptions)
- Type expectations from assertions

### 4. Use Type Tracer (If Tests Exist)

If tests exist, consider running the type tracer:

```bash
ruby scripts/type_tracer.rb -c 'TargetClass' -f json path/to/test.rb
```

Review tracer output to inform type decisions.

### 5. Add Magic Comment

Ensure the file has the magic comment at the top:

```ruby
# rbs_inline: enabled
```

### 6. Add Inline Annotations

Add type annotations using comment syntax:

**Method signatures:**
```ruby
#: (String, Integer) -> String
def format(text, width)
```

**Attributes:**
```ruby
attr_reader :name #: String
attr_accessor :count #: Integer?
```

**Instance variables:**
```ruby
# @rbs @items: Array[String]
```

**Blocks:**
```ruby
#: () { (String) -> void } -> void
def each(&block)
```

**Generics:**
```ruby
# @rbs generic T
class Container
```

### 7. Generate and Validate

Generate RBS from inline annotations:

```bash
bundle exec rbs-inline --output lib
```

Then validate:

```bash
bundle exec steep check lib/target.rb
```

Fix any errors before completing.

## Output

1. Modified Ruby file(s) with inline type annotations
2. Generated `sig/generated/*.rbs` files (if --output used)
3. Report what was typed and any decisions made

## Tips

- Always add `# rbs_inline: enabled` at file top
- Use `#:` for concise method signatures
- Use `# @rbs` for structured annotations with comments
- Use `# @rbs!` for DSL-generated methods
- Check `references/troubleshooting.md` for common gotchas
- Instance variable nil checks need local variable assignment for narrowing
