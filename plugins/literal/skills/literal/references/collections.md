# Generic typed collections: `Literal::Array`, `Set`, `Hash`, `Tuple`

These are *containers* that wrap a Ruby collection and check element types on read, write, mutation, and combination operations. Build them with the constructors `Literal::Array(t)`, `Literal::Set(t)`, `Literal::Hash(k, v)`, `Literal::Tuple(*types)`.

Don't confuse with the *type matchers* `_Array(t)`, `_Set(t)`, `_Hash(k,v)`, `_Tuple(*types)` from `Literal::Types`. Those describe shape and check from outside; the containers below *are* the collection.

## Constructors and `=== `

```ruby
Literal::Array(String)         # a Generic - call .new with elements
Literal::Set(Integer)
Literal::Hash(Symbol, String)
Literal::Tuple(String, Integer, Integer)

Literal::Array(String).new("a", "b", "c")
Literal::Hash(Symbol, Integer).new(a: 1, b: 2)
Literal::Tuple(String, Integer).new("a", 1)
```

The Generics are themselves `===`-able and respect type covariance:

```ruby
Literal::Array(Numeric) === Literal::Array(Integer).new(1)   # true (covariant)
Literal::Array(Integer) === Literal::Array(Numeric).new(1)   # false (refused)
```

`Literal.subtype?(Literal::Array(Integer), Literal::Array(Numeric))` is true.

## `Literal::Array(t)`

The most fully-featured of the four. Supports almost all of Ruby's `Array` API, but every mutation that adds elements is type-checked.

```ruby
arr = Literal::Array(Integer).new(1, 2, 3)

arr << 4                    # ok
arr << "5"                  # raises Literal::TypeError
arr.push(5, 6)              # ok (multi-value, all checked)
arr[0] = 10                 # ok
arr[0] = "10"               # raises
arr + [4, 5]                # checks RHS, returns new Literal::Array(Integer)
arr.map(String, &:to_s)     # MUST pass the new element type explicitly
arr.map(Integer, &:succ)    # same: type required
arr.map!(&:succ)            # mutates in place; checks remain Integer
arr.narrow(Numeric)          # widen/narrow the static element type if values fit

arr.to_a                    # returns a *copy* of the inner array
arr.__value__               # internal array (don't mutate this directly)
```

Notable methods/behaviours:

- `map(type, &block)` requires the result element type as a positional arg. Literal uses a `Transforms` table (e.g. `Integer#succ` is known to return `Integer`) to validate optimistically; if the function returns a value not matching `type`, the per-element type check raises.
- `map!(&block)` does not need the type because it must remain the same.
- `+`, `|`, `replace` accept either another `Literal::Array` of the same type or a regular `Array` whose elements pass the type check.
- `&`, `-`, `*` (with int), `<=>`, `<<`, `delete*`, `take*`, `drop*`, `select*`, `reject*`, `reverse*`, `rotate*`, `sort*`, `shuffle*`, `flatten*`, `uniq*` are all supported.
- `compact` currently returns a copy with the same type (TODO marker in source).
- `product(other_literal_arrays)` returns a `Literal::Array(Literal::Tuple(...))`; with a block, it yields tuples and returns self.
- `transpose` is type-aware: an Array of Tuples transposes into a Tuple of Arrays.
- `zip` builds an `Array(Tuple(...))` based on the input types; raises if length mismatch and the type is not nilable.
- `narrow(t)` *narrows* the declared element type to a subtype of the current one. The new type is checked: `Literal.subtype?(t, current_type)` must hold, else `ArgumentError`. If the declared type is actually changing, every existing element is also re-checked at runtime. Use this on a `Literal::Array(Numeric)` you've discovered actually only contains Integers, to get a `Literal::Array(Integer)` back. Widening (e.g. `Integer` -> `Numeric`) is rejected.

Errors carry useful path info: `Literal::Array(Integer)` raising on `[]=` reports `#[]=`, on `<<` reports `#<<`, etc.

## `Literal::Set(t)`

Wraps a Ruby `Set`. `Literal::Set(Integer).new(1, 2, 2, 3)` collapses duplicates and enforces type. Most `Set` methods are forwarded.

## `Literal::Hash(key_t, value_t)`

Wraps a Ruby `Hash`. Both keys and values are type-checked on insertion.

```ruby
Literal::Hash(Symbol, Integer).new(a: 1, b: 2)
```

## `Literal::Tuple(*types)`

Fixed-arity heterogeneous container.

```ruby
t = Literal::Tuple(String, Integer).new("a", 1)
```

Tuples participate in the type hierarchy via element-wise subtype, and they're produced by `Literal::Array#zip`, `#product`, and `#transpose`.

## Coercion / `to_proc`

Every Generic has `coerce(value)` that wraps a plain Ruby `Array`/`Set`/`Hash`, and `to_proc` to use it as a mapper:

```ruby
Literal::Array(String).coerce(["a", "b"])
# => Literal::Array(String) with the same elements

[["a", "b"]].map(&Literal::Array(String))   # uses to_proc
```

## When to wrap vs use type matchers

Use a `Literal::Array(...)` when you want to enforce types **on every mutation**, not just at construction. If you just need to type-check on input but otherwise pass a plain Ruby Array around, use the matcher `_Array(t)` in your `prop` / `Literal.check` and skip the wrapper.

```ruby
# Type-checked on initialize, then it's a plain Array under the hood
prop :tags, _Array(Symbol)

# Type-checked on every push/<</[]= - wrapper holds invariants forever
prop :tags, Literal::Array(Symbol), default: -> { Literal::Array(Symbol).new }
```

The generic wrappers carry a small per-call overhead since each mutation checks types. Tight loops with very small element types may want a plain `Array` and a one-shot validation.
