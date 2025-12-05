# Steep Type Checker Integration

## Installation

```bash
# Add to Gemfile
bundle add rbs-inline --require=false  # For inline RBS
bundle add steep --group=development

# Or manually in Gemfile:
gem 'rbs-inline', require: false
gem 'steep', group: :development
```

**Important**: Use `--require=false` for rbs-inline to avoid runtime dependencies.

## Initial Setup

```bash
# Generate Steepfile
bundle exec steep init

# Initialize RBS collection for gem types
bundle exec rbs collection init

# Install gem type definitions
bundle exec rbs collection install
```

## Steepfile Configuration

### Basic Configuration

```ruby
# Steepfile
D = Steep::Diagnostic

target :app do
  check "lib"                          # Ruby source directories
  check "app"

  signature "sig"                       # Standalone RBS files
  signature "sig/generated"             # Generated from inline RBS

  library "pathname", "json", "logger"  # Standard libraries

  collection_config "rbs_collection.yaml"
end
```

### Multiple Targets

```ruby
target :app do
  check "app", "lib"
  signature "sig"

  configure_code_diagnostics(D::Ruby.strict)
end

target :test do
  check "test"
  signature "sig", "sig/test"

  unreferenced!
  configure_code_diagnostics(D::Ruby.lenient)
end

target :scripts do
  check "script"
  signature "sig"

  implicitly_returns_nil!
end
```

### Diagnostic Configuration

```ruby
target :app do
  # Diagnostic severity templates:
  # D::Ruby.default  - Basic type checking
  # D::Ruby.strict   - Comprehensive (recommended)
  # D::Ruby.lenient  - Minimal checking
  # D::Ruby.silent   - No diagnostics

  configure_code_diagnostics(D::Ruby.strict) do |hash|
    # Customize specific diagnostics
    # Severity levels: :error, :warning, :hint, nil (ignore)

    hash[D::Ruby::NoMethod] = :error
    hash[D::Ruby::MethodArityMismatch] = :error
    hash[D::Ruby::IncompatibleArguments] = :error
    hash[D::Ruby::ReturnTypeMismatch] = :warning
    hash[D::Ruby::BlockTypeMismatch] = :warning
    hash[D::Ruby::UnsupportedSyntax] = :hint
    hash[D::Ruby::UnreachableValueBranch] = nil
  end
end
```

### Advanced Options

```ruby
target :app do
  check "lib"
  signature "sig"

  implicitly_returns_nil!    # Allow implicit nil returns
  unreferenced!              # Don't check for unreferenced code
end
```

## RBS Collection Configuration

RBS collection manages third-party gem type definitions, similar to Bundler for gems.

### rbs_collection.yaml

```yaml
sources:
  - name: ruby/gem_rbs_collection
    remote: https://github.com/ruby/gem_rbs_collection.git
    revision: main
    repo_dir: gems

  # Local source (optional)
  - type: local
    path: path/to/local/rbs

path: .gem_rbs_collection

gems:
  # Explicitly include a gem not in Gemfile.lock
  - name: csv

  # Exclude a gem's RBS (useful for compatibility issues)
  - name: nokogiri
    ignore: true

  # Include RBS for gem marked `require: false` in Gemfile
  - name: rbs
    ignore: false
```

### Controlling RBS Installation

Two ways to skip RBS for a gem:

1. **In Gemfile** (recommended): `gem 'name', require: false`
2. **In rbs_collection.yaml**: Add `ignore: true`

Gems with `require: false` in Gemfile won't have RBS installed unless you add `ignore: false` in rbs_collection.yaml.

### manifest.yaml (For Gem Authors)

Declare implicit stdlib dependencies your gem uses:

```yaml
# sig/manifest.yaml
dependencies:
  - name: pathname
  - name: json
  - name: set
```

Place in `sig/manifest.yaml` for gems with bundled RBS, or `gems/GEM_NAME/VERSION/manifest.yaml` in gem_rbs_collection.

### Files to Commit

| File | Commit? | Notes |
|------|---------|-------|
| `rbs_collection.yaml` | Yes | Configuration |
| `rbs_collection.lock.yaml` | Yes | Lock file for reproducibility |
| `.gem_rbs_collection/` | No | Downloaded RBS files (add to .gitignore) |

### .gitignore

```gitignore
/.gem_rbs_collection/
```

## Workflow Commands

### Generate Inline RBS

```bash
# Generate to stdout
bundle exec rbs-inline lib

# Save to sig/generated (default output directory)
bundle exec rbs-inline --output lib

# Watch for changes
bundle exec rbs-inline --watch lib
```

**Important**: `rbs-inline --output` generates files to `sig/generated/` by default, not `sig/`. Update your Steepfile accordingly:

```ruby
target :app do
  signature "sig/generated"    # For rbs-inline output
  signature "sig"              # For hand-written RBS files
end
```

### Type Checking

```bash
# Check all targets
bundle exec steep check

# Check specific file
bundle exec steep check lib/user.rb

# Check specific target/group
bundle exec steep check --group=app

# Watch mode
bundle exec steep watch

# Show type at position
bundle exec steep hover lib/file.rb:10:5

# Get completions
bundle exec steep complete lib/file.rb:10:5
```

### Language Server

```bash
# Start for editor integration
bundle exec steep langserver
```

Works with VSCode (Steep extension), Vim (LSP), Emacs (lsp-mode).

### RBS Commands

```bash
# Validate RBS syntax
bundle exec rbs validate

# Update gem types
bundle exec rbs collection update

# Clean unused types
bundle exec rbs collection clean
```

## Common Diagnostics

### Ruby Diagnostics

| Diagnostic | Description |
|------------|-------------|
| `NoMethod` | Method not found on type |
| `MethodArityMismatch` | Wrong number of arguments |
| `IncompatibleArguments` | Argument type mismatch |
| `ReturnTypeMismatch` | Return doesn't match signature |
| `BlockTypeMismatch` | Block type mismatch |
| `IncompatibleAssignment` | Assignment type mismatch |
| `UnreachableBranch` | Dead code |
| `RequiredKeywordArgumentMissing` | Missing required keyword |

### RBS Diagnostics

| Diagnostic | Description |
|------------|-------------|
| `UnknownConstant` | Constant not found |
| `DuplicatedMethodDefinition` | Method defined twice |
| `InvalidTypeApplication` | Wrong generic arguments |

## CI Integration

### GitHub Actions

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

      - name: Install RBS Collection
        run: bundle exec rbs collection install

      - name: Generate Inline RBS
        run: bundle exec rbs-inline --output lib

      - name: Run Steep
        run: bundle exec steep check
```

### Rake Task

```ruby
# Rakefile
desc "Type check with Steep"
task :typecheck do
  sh "bundle exec rbs collection install"
  sh "bundle exec rbs-inline --output lib"
  sh "bundle exec steep check"
end

task default: [:test, :typecheck]
```

## Debugging

```bash
# Show inferred type at location
bundle exec steep hover lib/file.rb:10:5

# Verbose output
STEEP_LOG_LEVEL=debug bundle exec steep check

# Type checking stats
bundle exec steep stats
```

## Troubleshooting

**Issue**: Missing gem types
```bash
bundle exec rbs collection list
bundle exec rbs collection update
```

**Issue**: Too many errors initially
```ruby
# Start lenient, increase strictness over time
configure_code_diagnostics(D::Ruby.lenient)
```

**Issue**: Slow type checking
```ruby
# Split into targeted checks
target :critical do
  check "app/models", "app/services"
end
```
