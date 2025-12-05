---
description: Convert standalone .rbs signature files to inline RBS annotations in Ruby source files. Supports multiple files and glob patterns.
argument-hint: <rbs_file_or_pattern>...
---

# Convert Standalone RBS to Inline Annotations

You are converting standalone `.rbs` signature files into inline RBS annotations embedded directly in Ruby source files.

**Target files:** $ARGUMENTS

## Process

### 1. Load the RBS Skill

First, load the RBS skill for comprehensive type knowledge:

```
Use the Skill tool to load: ruby-rbs
```

Read both subskills:
- `subskills/rbs-files/SKILL.md` - Understand standalone RBS format
- `subskills/inline/SKILL.md` - Learn inline annotation syntax

Also read the comparison reference:
- `references/comparing-signatures.md` - How to verify conversion

### 2. Resolve Target Files

Parse the user's arguments to find .rbs files to convert:

```bash
# If glob pattern provided
find sig -name "*.rbs" -not -path "*/generated/*" 2>/dev/null

# List what will be converted
ls -la $ARGUMENTS
```

Skip any files in `sig/generated/` (these are output from rbs-inline).

### 3. For Each .rbs File

#### 3.1 Find Corresponding Ruby File

Map the .rbs path to its Ruby source:
- `sig/user.rbs` → `lib/user.rb`
- `sig/my_app/models/user.rbs` → `lib/my_app/models/user.rb`
- `sig/app/models/user.rbs` → `app/models/user.rb`

If the Ruby file doesn't exist, report it and skip.

#### 3.2 Read Both Files

Read the .rbs file to understand what types need to be converted.
Read the Ruby file to know where to insert annotations.

#### 3.3 Convert and Insert

Transform each RBS declaration to inline syntax and insert at the correct location:

| Standalone | Inline |
|------------|--------|
| `def foo: (String) -> Integer` | `#: (String) -> Integer` above `def foo` |
| `attr_reader name: String` | `attr_reader :name #: String` |
| `@items: Array[String]` | `# @rbs @items: Array[String]` |
| `class Foo[T]` | `# @rbs generic T` after `class Foo` |
| `type callback = ...` | `# @rbs! type callback = ...` |

#### 3.4 Add Magic Comment

Ensure file starts with (after shebang/frozen_string_literal):

```ruby
# rbs_inline: enabled
```

### 4. Generate and Validate

After converting all files:

```bash
# Generate RBS from inline annotations
bundle exec rbs-inline --output lib

# Compare original with generated
bundle exec ruby scripts/compare_rbs.rb --dir sig/ sig/generated/

# Run type check
bundle exec steep check
```

### 5. Handle Results

**If comparison passes:**
```bash
# Backup original .rbs files
for f in $CONVERTED_FILES; do
  mv "$f" "${f}.bak"
done
```

**If differences found:**
- Report which methods/attributes differ
- Suggest fixes for the inline annotations
- Do NOT backup until user confirms resolution

## Output

Provide a summary:
1. **Converted:** List of Ruby files with new inline annotations
2. **Backed up:** Original .rbs files renamed to .rbs.bak
3. **Comparison:** Pass/fail status with any differences
4. **Type check:** Steep results
5. **Action needed:** Any manual fixes required

## Example

```
/convert-rbs-to-inline sig/user.rbs sig/post.rbs
```

Converts `sig/user.rbs` and `sig/post.rbs` to inline annotations in their corresponding Ruby files, validates the conversion, and backs up the originals.
