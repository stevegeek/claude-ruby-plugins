---
description: Write standalone RBS type signatures for Ruby files. Analyzes code, finds tests, traces types, and generates sig/*.rbs files.
argument-hint: <file_path>
---

# Write Standalone RBS Signatures

You are writing RBS type signatures in standalone `.rbs` files for the Ruby code at: $ARGUMENTS

## Process

### 1. Load the RBS Skill

First, load the RBS skill to get comprehensive type syntax knowledge:

```
Use the Skill tool to load: ruby-inline-rbs
```

Then read the standalone RBS subskill for file format details:
- `subskills/rbs-files/SKILL.md`

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

### 5. Generate Scaffold (Optional)

For complex files, generate an initial scaffold:

```bash
bundle exec rbs prototype rb lib/target.rb
```

### 6. Write RBS

Create the `.rbs` file in `sig/` mirroring the `lib/` structure:

```
lib/my_app/user.rb → sig/my_app/user.rbs
```

Follow these principles:
- Start with public API methods
- Use appropriate types (avoid `untyped` where possible)
- Consider generics for container classes
- Use interfaces for duck typing
- Add optional markers (`?`) for nilable returns

### 7. Validate

Run validation to check your work:

```bash
bundle exec rbs validate
bundle exec steep check lib/target.rb
```

Fix any errors before completing.

## Output

Create/update the following:
1. `sig/**/*.rbs` - Type signature files
2. Report what was typed and any decisions made

## Tips

- Match RBS file structure to Ruby file structure
- Don't type private implementation details unless needed
- Use `untyped` for genuinely dynamic/complex code
- Check gem_rbs_collection for third-party type definitions
- Reference `references/type-syntax.md` for syntax questions
