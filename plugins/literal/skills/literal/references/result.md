# `Literal::Result` - typed result monad

`Literal::Result(success_type, failure_type)` produces a generic result type with two outcomes: `Literal::Success` or `Literal::Failure`. Both branches are type-checked, both compose, and the `handle` API enforces exhaustiveness over the declared types.

The constructor is `Literal::Result(success_type, failure_type)` (top-level method on `Literal`). Without a block it returns the generic; with a block, it kicks off a `try`-style computation.

## Producing a result

### Without a block - construct directly

```ruby
type = Literal::Result(Integer, Symbol)

type.success(42)        # Literal::Success
type.failure(:nope)     # Literal::Failure
```

`type === some_result` returns true if the result's wrapped value/error matches the declared types.

### With a block - `try`

```ruby
result = Literal::Result(Integer, Symbol) do |type|
  raw = compute_something
  if raw < 0
    type.failure(:negative)
  else
    type.success(raw * 2)
  end
end
```

Inside the block, `type.success(...)` and `type.failure(...)` *throw* (they don't return). The block must throw a result; otherwise:

- Returning a non-result value raises `Literal::ArgumentError("Expected block to throw a success or failure result")`.
- Returning a `Literal::Result` (instead of throwing one) also raises.

Use `try` when you want to short-circuit early without wrapping each branch by hand.

## Inspecting

```ruby
result.success?     # true on Success, false on Failure
result.failure?     # opposite
result.value!       # raises Literal::ArgumentError on Failure
result.error!       # raises Literal::ArgumentError on Success
result.success_type # the Generic's success_type
result.failure_type # the Generic's failure_type
```

Pattern matching works because `deconstruct` and `deconstruct_keys` are implemented:

```ruby
case result
in Literal::Success[Integer]              # positional pattern (uses deconstruct)
  ...
in Literal::Success[message: String]      # keyword pattern (delegates to wrapped value)
  ...
in Literal::Failure[error]                # via deconstruct
  ...
end
```

## Combining

### `map(new_success_type, &block)`

Transform a Success's value into a new Success of `new_success_type`. On Failure, leaves the error and updates only the metadata.

```ruby
Literal::Result(Integer, Symbol) { |t| t.success(42) }
  .map(String, &:to_s)
# => Success("42") with success_type: String, failure_type: Symbol
```

### `also(&block)`

Yields the success value for side effects (logging, telemetry); returns *self*. Skipped on Failure.

```ruby
result.also { |value| logger.info("got #{value}") }
```

### `and_then(&block)`

Chain another result-producing computation. The block must return a `Literal::Result`. The success type adopts the new block's success type; the failure type *unions* with the new failure type.

```ruby
result = Literal::Result(Integer, Symbol) { |t| t.success(42) }
  .and_then { |v| Literal::Result(String, RuntimeError) { |t| t.success(v.to_s) } }

result.success_type    # String
result.failure_type    # _Union(Symbol, RuntimeError)
```

If the original is a Failure, `and_then` returns the original unchanged (no yield).

If the block returns a non-Result, it raises `Literal::ArgumentError("Expected block to return a Literal::Result, got <Class>")`.

### `value_or(&block)`

```ruby
result.value_or { |error| default_for(error) }   # Success returns value!; Failure yields the error
```

Block is required. (Pass `{ raise }` to make Failures fatal.)

## `handle` - exhaustive case-style branching

```ruby
result = Literal::Result(String, Symbol) { |t| t.success("hello") }

handled = result.handle do |on|
  on.success(String, &:upcase)
  on.failure(Symbol) { |error| "error: #{error}" }
end
# => "HELLO"
```

`handle` requires that every branch of the success type and the failure type is covered. With a Union type, you can split:

```ruby
result = Literal::Result(_Union(String, Integer), Symbol) { |t| t.success("hi") }

result.handle do |on|
  on.success(String, &:upcase)
  on.success(Integer) { |v| v + 1 }
  on.failure(Symbol)                # no block = ignore, returns nil
end
```

If you don't cover every type, `handle` raises:

```
Literal::ArgumentError: No success handler covers <Type>
```

This is computed via `Literal.subtype?` over the union of declared handler types vs. the result's declared type. So as long as your handlers cover the *declared* types, you're safe.

Branches without blocks return `nil` for that case - useful for ignoring parts of a Union you don't care about.

## When to use Result

- Multi-step pipelines where intermediate failures should propagate without exceptions polluting the control flow.
- Explicit failure typing where callers should understand the shape of "what could go wrong".
- API responses that distinguish "we know this is a known failure" from "we hit an exception".

When *not* to use Result:

- Simple two-state code where a `nil` return is fine.
- Code that's already heavy with exceptions and would gain little from wrapping every call.

## Composition example

```ruby
def fetch_user(id)
  Literal::Result(User, Symbol) do |type|
    record = db.find(id)
    record ? type.success(record) : type.failure(:not_found)
  end
end

def authorize(user, action)
  Literal::Result(User, Symbol) do |type|
    user.allowed?(action) ? type.success(user) : type.failure(:forbidden)
  end
end

fetch_user(42)
  .and_then { |u| authorize(u, :delete) }
  .map(String) { |u| u.email }
  .handle do |on|
    on.success(String) { |email| "deleted #{email}" }
    on.failure(Symbol) { |reason| "could not delete: #{reason}" }
  end
```
