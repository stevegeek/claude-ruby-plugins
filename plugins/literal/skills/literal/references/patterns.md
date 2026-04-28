# Patterns and gotchas across the library

A grab bag of recurring patterns and surprises from real Literal use. Many of these are not documented elsewhere - they come from reading the test suite and source.

## Convention: `===` over `is_a?`

Per the project's `AGENTS.md`: never use `is_a?`. Prefer `===`, `in`, or `case`/`when`. The whole library is built on `===` - that's why a Range, a class, a Regexp, or a Literal type matcher all work interchangeably as "types". `is_a?` asks the wrong object.

## Mix `Literal::Types` for inline use

`Literal::Properties` already includes `Literal::Types`, so inside `class X < Literal::Object` (or anywhere `extend Literal::Properties`), `_Foo` matchers are available with no extra setup.

For top-level use (e.g. tests, scripts) and within other classes, `include` or `extend` `Literal::Types` explicitly:

```ruby
include Literal::Types        # adds _Foo as private instance methods to top level
extend Literal::Types         # adds _Foo as singleton methods of self
```

## `prop` declaration order matters

The generated initializer follows Ruby parameter ordering: positional, splat, keyword, double-splat, block. Within a kind, declaration order wins. If you need a positional arg, declare it before any keyword props you want to keep.

## Defaults must be frozen or a Proc

`prop :tags, _Array(Symbol), default: []` raises `Literal::ArgumentError` because `[]` is mutable and unfrozen. Use `default: -> { [] }` instead. Symbols, true/false, nil, frozen string literals, and integers/floats/etc. are all fine as bare defaults.

## `prop` with a default and a `_Nilable` type

If you want "nil-or-default" semantics, `default:` and `_Nilable(...)` compose:

```ruby
prop :name, _Nilable(String), default: nil          # explicit; redundant default
prop :name, _Nilable(String)                        # nil acceptable, but no default
prop :name, String, default: "Anonymous"            # required + fallback when omitted
```

## Distinguish "not provided" from "provided as nil" with `prop?`

```ruby
prop? :name, String

instance.literal_properties[:name].default        # Literal::Undefined
```

`prop?` typesigs as `_Union(t, Literal::Undefined)` and defaults to `Undefined`. Read the value to check `Literal::Undefined === value`.

## `Literal::Value(t)` is *not* `t`

A `Literal::Value(String)` instance does not satisfy `String === self`. If you need to pass it to something expecting a real String, call `.to_s` (auto-aliased) or `.value`.

```ruby
Email = Literal::Value(String) { delegate :length }
e = Email.new("a@b.com")
String === e         # false
Email === e          # true
e.to_s               # "a@b.com"  (auto-alias because subtype of String)
```

If you'd rather a brand that *does* slot in everywhere a String works, use `Literal::Delegator(String)`.

## Generic collections vs collection type matchers

| | Type matcher (`_Array(t)`) | Generic container (`Literal::Array(t)`) |
|---|---|---|
| Use case | "Hey, validate this Hash/value once" | "Hold a typed array, enforce on every mutation" |
| Storage | underlying Ruby `Array` | wrapped, with metadata |
| Mutation guard | none (it's a one-shot check) | every `<<`, `[]=`, `push`, `+`, etc. |
| `to_a` | n/a | returns a copy |

If your code path mutates the collection beyond construction and you want each mutation typed, use the wrapper. If construction is the only place values enter the collection, the matcher is enough and cheaper.

## Subtype relationships you should remember

- `Literal::Array(Sub) < Literal::Array(Super)` (covariant)
- `_Tuple(Sub, Sub) < _Tuple(Super, Super)` (covariant on every position)
- `_Constraint(K, size: 1..2) < _Constraint(K, size: 1..5)` (range coverage)
- `_TaggedUnion(name: String, age: Integer) < _Union(String, Integer)` (every tag's type lives in the union)

These power exhaustiveness in `Result#handle` and `narrow` in `Literal::Array`.

## Frozen-by-default surface

The following are *frozen on construction*:

- `Literal::Value` instances
- `Literal::Delegator` instances
- `Literal::Data` instances (and their property values where possible)
- `Literal::Flags` instances
- `Literal::Enum` instances (after class definition)
- The Generic objects themselves (`Literal::Array(String)`, `Literal::Tuple(...)`, etc.)
- All `Literal::Types::*` matcher instances

If a method returns `self` from a Generic, that doesn't unfreeze it - it's just chaining. Use the `__with__` / `with` patterns on Flags/Tuples for "modify a copy".

## Inheritance overrides `prop`

Re-declaring a prop in a subclass overwrites the parent's. Use this to narrow a type:

```ruby
class Person < Literal::Object
  prop :age, Integer, reader: :public
end

class Friend < Person
  prop :age, Float, reader: :public
end
```

`literal_properties` is `dup`'d, not shared, so changes don't leak upward.

## After-initialize hook

Define `after_initialize` (any visibility - public/protected/private all run). Use for invariants spanning multiple props.

## Marshalling needs named classes

`Marshal.dump` / `Marshal.load` round-trips work for `Literal::Struct`, `Data`, `Value`, `Enum` only when the class is *named* (assigned to a constant). Anonymous `Class.new(Literal::Struct)` won't survive Marshal.

`as_pack` / `from_pack` is the explicit alternative on most types - it returns a frozen array payload.

## Error messages have a backtrace shift

The generated initializer includes:

```ruby
rescue Literal::TypeError => error
  error.set_backtrace(caller(2))
  raise
```

So the error backtrace points at *the caller of `Klass.new`*, not Literal's internals. If you're debugging a stack trace and a Literal::TypeError seems mysterious, check `caller(2)` is the right frame in your context.

## Pattern matching is well-supported

Most Literal-built objects implement `deconstruct` and `deconstruct_keys`:

```ruby
case x
in Person(name: "Joel", age: Integer => age)
in Literal::Success[Integer]
in Literal::Failure(Symbol)
in { bold: true, italic: true }   # via Flags#deconstruct_keys
in [Integer, String, Symbol]      # via Tuple#deconstruct
end
```

## Don't use `:class` as a reader name

`prop :class, ..., reader: :public` raises. Reason: `Object#class` is what Literal itself uses to inspect instances. You can still *store* a property called `:class` (just leave the reader off and define one manually if you really need it).

## Recursive types via `_Deferred`

When a type refers to a constant that hasn't been defined yet (autoload, mutual recursion):

```ruby
class Tree < Literal::Object
  prop :value, Integer
  prop :children, _Array(_Deferred { Tree }), default: -> { [] }
end
```

`_Deferred { ... }` evaluates its block lazily on first use.

## Predicate type recursion policy

`_Predicate("msg") { |v| ... }` defaults to `recursion: :reject` - if the predicate is asked to match the *same* object it's currently matching (deep cycle), it returns false. Pass `recursion: :accept` for "treat cycles as okay".

## Performance notes

- Property writers and the generated `initialize` are real Ruby methods, JIT-friendly. They're fast.
- `Literal::Array` mutation methods carry a per-call type check; not free in a tight loop.
- `Literal::Result#handle` runs `Literal.subtype?` over your handlers vs. the result's declared types on every call. For hot paths, prefer manual `case/when`.
- `Literal.subtype?` memoizes via `SubtypeContext` so cyclic types don't blow up.

## What Literal doesn't do

- It doesn't generate types from existing code (no inference).
- It doesn't replace Sorbet/RBS - it complements them. (Many people use both: RBS for static, Literal for the dynamic boundaries.)
- It doesn't watch for type errors statically; everything is runtime.
- It doesn't handle async/concurrency primitives - it's pure data shape.

## Quick recipe: a typed boundary

When wrapping an external interface (HTTP, a queue, a CLI), this is the canonical pattern:

```ruby
ParamsType = _Map(
  user_id: _Integer(1..),
  email: _Predicate("Email") { |s| String === s && s.include?("@") },
  preferences: _Hash(Symbol, _Boolean)
)

def perform(raw_params)
  Literal.check(raw_params, ParamsType) do |c|
    c.fill_receiver(receiver: self, method: "#perform")
  end
  do_the_work(raw_params)
end
```

One typed boundary, then everything inside is well-shaped.
