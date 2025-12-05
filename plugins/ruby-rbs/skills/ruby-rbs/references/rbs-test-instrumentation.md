# Runtime Testing with rbs/test

Test RBS signatures against actual runtime behavior by instrumenting method calls. This catches mismatches between signatures and implementation.

## Setup

Load `rbs/test/setup` before running tests:

```bash
# Via command line
ruby -r rbs/test/setup test/my_test.rb

# Via RUBYOPT
RUBYOPT='-rrbs/test/setup' rake test

# With Bundler
RUBYOPT='-rbundler/setup -rrbs/test/setup' bundle exec rake test
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `RBS_TEST_TARGET` | Classes to test (comma-separated, supports `*` wildcard) |

```bash
RBS_TEST_TARGET='MyApp::User'           # Single class
RBS_TEST_TARGET='MyApp::User,MyApp::*'  # Multiple patterns
RBS_TEST_TARGET='MyApp::*'              # All classes under MyApp
```

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `RBS_TEST_SKIP` | Classes to exclude from testing | - |
| `RBS_TEST_OPT` | RBS options (`-r`, `-I`) | `-I sig` |
| `RBS_TEST_LOGLEVEL` | Log level: debug, info, warn, error | `info` |
| `RBS_TEST_RAISE` | Raise exception on type error | `false` |

```bash
# Load stdlib and custom signature path
RBS_TEST_OPT='-r set -r pathname -I sig'

# Skip problematic classes
RBS_TEST_SKIP='MyApp::Legacy,MyApp::Generated'

# Debug mode - raises on first error with backtrace
RBS_TEST_RAISE=true
```

## Full Example

```bash
RBS_TEST_LOGLEVEL=error \
RBS_TEST_TARGET='MyApp::*' \
RBS_TEST_SKIP='MyApp::MonkeyPatch' \
RBS_TEST_OPT='-r json -r pathname -I sig' \
RBS_TEST_RAISE=true \
RUBYOPT='-rbundler/setup -rrbs/test/setup' \
bundle exec rake test
```

## Error Types

### ArgumentTypeError / BlockArgumentTypeError

Wrong argument type passed:

```
[MyApp::User.new] ArgumentTypeError: expected `::String` (email) but given `:"user@example.com"`
```

**Fix**: Check signature parameter types match actual usage.

### ArgumentError / BlockArgumentError

Wrong number of arguments or missing required argument:

```
[MyApp::User.new] ArgumentError: expected method type (name: ::String, email: ::String) -> ::MyApp::User
```

**Fix**: Ensure optional parameters use `?` prefix.

### ReturnTypeError / BlockReturnTypeError

Return value doesn't match signature:

```
[MyApp::User#name] ReturnTypeError: expected `::String` but returns `nil`
```

**Fix**: Update return type (e.g., `String` → `String?`).

### UnexpectedBlockError / MissingBlockError

Block given when not expected, or missing when required:

```
[MyApp::List#each] MissingBlockError: block is required for `() { (String) -> void } -> void`
```

**Fix**: Add `?` before block type for optional blocks: `?{ (T) -> void }`.

### UnresolvedOverloadingError

None of the overloaded signatures match:

```
[MyApp::Parser#parse] UnresolvedOverloadingError: ...
```

**Fix**: Review all overload variants; one should match the actual call.

### DuplicatedMethodDefinitionError

Method defined multiple times without `...` syntax:

```rbs
# Wrong - duplicate definition
class Foo
  def bar: () -> void
end
class Foo
  def bar: () -> String  # Error!
end

# Right - use ... to extend
class Foo
  def bar: () -> void
end
class Foo
  def bar: () -> String
         | ...
end
```

## Skipping Methods

Use `%a{rbs:test:skip}` annotation to skip instrumenting specific methods:

```rbs
class String
  %a{rbs:test:skip} def =~: (Regexp) -> Integer?
end
```

Useful for methods with complex behavior that's hard to type precisely.

## How It Works

The test framework uses `Module#prepend` to instrument target classes. For each method:

1. Wraps method with type-checking proxy
2. Validates argument types on call
3. Validates return type after call
4. Reports errors to logger (or raises if `RBS_TEST_RAISE=true`)

## CI Integration

```yaml
# .github/workflows/rbs-test.yml
name: RBS Runtime Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Run tests with RBS instrumentation
        env:
          RBS_TEST_TARGET: 'MyApp::*'
          RBS_TEST_OPT: '-I sig'
          RUBYOPT: '-rbundler/setup -rrbs/test/setup'
        run: bundle exec rake test
```

## Tips

1. Start with `RBS_TEST_LOGLEVEL=error` to reduce noise
2. Use `RBS_TEST_RAISE=true` locally to get backtraces
3. Add `RBS_TEST_SKIP` for generated/metaprogrammed code
4. Run alongside regular tests - it's non-intrusive
5. Combine with Steep for both static and runtime checking
