# Runtime checking primitives

The high-level Literal classes (`Properties`, `Struct`, `Data`, `Value`, generic collections) all funnel into the same low-level checking API. You can use these directly when you need ad-hoc validation without inheriting from anything.

## `Literal.check(value, type, &block)`

Raises `Literal::TypeError` if `type === value` is false; otherwise returns `true`.

```ruby
include Literal::Types

Literal.check("Joel", String)               # => true
Literal.check(17, _Integer(18..))           # raises Literal::TypeError
Literal.check([1, "x"], _Array(Integer))    # raises Literal::TypeError, points at index 1
```

The optional block is called *before* raising with the `Literal::TypeError::Context`, letting you decorate the error with the receiver and method:

```ruby
Literal.check(value, _Array(Integer)) do |context|
  context.fill_receiver(receiver: self, method: "#my_method")
end
```

That's how the gem's own collections produce nice messages like:

```
Type mismatch

Foo#my_method (from .../caller.rb:12)
  [0]
    Expected: Integer
    Actual (String): "x"
```

## `Literal.subtype?(t, u, context: nil)`

Predicate: does every value of `t` satisfy `u`? It's the gem's centralized subtype relation, used internally by `Literal::Result#handle` (exhaustiveness), generic collection covariance, `narrow`, and `_Constraint` hierarchy.

```ruby
Literal.subtype?(Integer, Numeric)                          # true
Literal.subtype?(Integer, Float)                            # false
Literal.subtype?(_Array(Integer), _Array(Numeric))          # true
Literal.subtype?(1..3, Integer)                             # true (range coverage)
Literal.subtype?(_Constraint(Array, size: 1..2), _Constraint(Array, size: 1..5))  # true
```

It handles cycles via a `SubtypeContext` memo so recursive types don't spin.

## `Literal::TypeError`

A `TypeError` subclass with a structured `Context`:

```ruby
begin
  Literal.check([1, "x"], _Array(Integer))
rescue Literal::TypeError => e
  e.message      # human-readable nested message
  e.to_h         # full structured context tree
  e.deconstruct_keys([:expected, :actual])  # pattern-matchable
end
```

The context tree includes `receiver`, `method`, `label` (e.g. `"name"` or `"name:"`), `expected`, `actual`, and recursive `children`. Custom types can decorate it by implementing `record_literal_type_errors(context)`.

## `Literal::ArgumentError`

Raised when *Literal itself* is misused - e.g., you passed an invalid `default:` (mutable & unfrozen), an invalid kind, or you tried to redefine a value in an Enum. Distinct from `Literal::TypeError` to keep the two failure modes separate.

## `Literal::Type` mixin

If you're building a *new* type matcher, include `Literal::Type`. It opts you into the subtype protocol:

- Define `===` for value matching
- Optionally define `>=` (or `<=`) for subtype answers
- Optionally `record_literal_type_errors(context)` for nicer errors

The built-in `Literal::Types::*` classes all use this pattern.

## `Literal.Brand(...)` (and the freezing dance)

```ruby
Literal::Brand.new(...)
Literal.Brand(...)
```

This is a *less commonly used* API for branding values - tagging a primitive with a phantom subtype so you can distinguish, say, `EmailAddress` from `String` without wrapping. (If you find yourself reaching for this, think first whether `Literal::Value(String)` would do.)

## Match guard

`Literal.with_match_guard(type, value) { ... }` is an internal helper that tracks recursive `===` calls per thread via a key of `[type.class, type.object_id, value.object_id]`. Used by `_Union` and `_TaggedUnion` to avoid infinite recursion when a self-referential type sees itself.

You shouldn't normally call this; it's documented here because you may see it in stack traces if a custom type composes recursively.

## Bare-hands example

```ruby
require "literal"
include Literal::Types

EmailType = _Predicate("Email") { |s| String === s && s.include?("@") }
PhoneType = _Pattern(/\A\+?[\d\s-]{7,}\z/) { true }
ContactType = _Map(name: _String(size: 1..100), email: EmailType, phone: _Nilable(PhoneType))

def create_contact(attrs)
  Literal.check(attrs, ContactType) do |c|
    c.fill_receiver(receiver: self, method: "#create_contact")
  end

  Contact.new(**attrs)
end
```

This pattern - declare a type, `Literal.check` once at the boundary, then proceed with confidence - is a tidy way to add a sanity check to an external interface (a Sidekiq job, a Sinatra route, a CLI parser) without changing the underlying classes.
