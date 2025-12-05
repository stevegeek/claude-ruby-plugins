# Comparing RBS Signatures

Use `scripts/compare_rbs.rb` to verify that generated RBS files (from `rbs-inline`) match original hand-written signatures. This is essential when converting from standalone RBS to inline annotations.

## Usage

```bash
# Compare two specific files
bundle exec ruby scripts/compare_rbs.rb sig/user.rbs sig/generated/user.rbs

# Compare all .rbs files in directories
bundle exec ruby scripts/compare_rbs.rb --dir sig/ sig/generated/

# JSON output for programmatic use
bundle exec ruby scripts/compare_rbs.rb --json sig/user.rbs sig/generated/user.rbs

# Quiet mode (only output on failure)
bundle exec ruby scripts/compare_rbs.rb --quiet --dir sig/ sig/generated/
```

## Options

| Option | Description |
|--------|-------------|
| `--dir` | Compare all `.rbs` files in two directories recursively |
| `--json` | Output results as JSON instead of human-readable format |
| `--quiet` | Suppress output unless differences found |
| `--strict-param-names` | Treat parameter names as significant (default: ignore them) |
| `-h, --help` | Show usage information |

### Parameter Name Handling

By default, the script ignores parameter names when comparing signatures. This means `(Object? value)` and `(Object?)` are considered equivalent since parameter names are semantically irrelevant in RBS.

Use `--strict-param-names` if you want exact matching including parameter names:

```bash
bundle exec ruby scripts/compare_rbs.rb --strict-param-names sig/user.rbs sig/generated/user.rbs
```

## Exit Codes

- `0` - All comparisons passed (signatures match)
- `1` - Differences found or error occurred

## What It Compares

The script parses both RBS files and compares:

- **Classes and Modules** - Presence and names
- **Methods** - Signatures, overloads, visibility, return types
- **Attributes** - `attr_reader`, `attr_writer`, `attr_accessor` with types
- **Instance Variables** - `@var` type declarations
- **Constants** - Name and type
- **Includes/Extends** - Module mixins

## Output Format

### Human-Readable (default)

```
============================================================
RBS Comparison Results
============================================================

✅ sig/user.rbs
⚠️  sig/post.rbs - 2 difference(s)
   - In original only: method :legacy_format
   ~ Method signature differs: :create
     Original:  (String, Integer) -> Post
     Generated: (String, ?Integer) -> Post
❌ sig/comment.rbs - Generated file not found

============================================================
Some RBS files have differences ❌
============================================================
```

### JSON Output

```json
{
  "passed": false,
  "total": 3,
  "passed_count": 1,
  "failed_count": 2,
  "results": [
    { "file": "sig/user.rbs", "status": "ok" },
    {
      "file": "sig/post.rbs",
      "status": "different",
      "differences": [
        {
          "type": "missing_in_generated",
          "class": "Post",
          "member_type": "method",
          "method": "legacy_format"
        }
      ]
    }
  ]
}
```

## Workflow: Converting Standalone to Inline RBS

1. **Add inline annotations** to Ruby source files
2. **Generate RBS** from inline: `bundle exec rbs-inline --output lib`
3. **Compare** original with generated:
   ```bash
   bundle exec ruby scripts/compare_rbs.rb sig/user.rbs sig/generated/user.rbs
   ```
4. **Fix any differences** by adjusting inline annotations
5. **Re-generate and re-compare** until they match
6. **Backup original**: `mv sig/user.rbs sig/user.rbs.bak`

## Common Difference Types

| Difference | Meaning | Fix |
|------------|---------|-----|
| `missing_in_generated` | Method/attr in original but not generated | Add inline annotation for this method |
| `missing_in_original` | Extra item in generated (usually okay) | May indicate extra annotation or generated cruft |
| `method_mismatch` | Signature differs | Check parameter types, optionality, return type |

## Limitations

- Does not compare type aliases (these may need manual verification)
- Does not compare interfaces defined at top level
- Parameter names are compared but may differ without semantic impact
- Comments and documentation are not compared
