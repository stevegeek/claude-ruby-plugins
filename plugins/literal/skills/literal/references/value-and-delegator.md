# `Literal::Value` and `Literal::Delegator`

Both let you wrap a single underlying value behind a typed class, useful for primitive-obsession refactors and for adding behaviour to scalar types. They differ in *which methods* the wrapper exposes.

## `Literal::Value(type, *constraints, **kw)`

A frozen wrapper holding a single typed value. Methods of the inner type are *not* automatically exposed - you opt in.

```ruby
UserID = Literal::Value(Integer)
Age = Literal::Value(Integer, 18..)         # extra constraint
Name = Literal::Value(String) do
  delegate :length                          # explicitly expose String#length
end

user_id = UserID.new(123)
user_id.value      # => 123
user_id.to_i       # => 123 (auto-aliased, see below)

Age.new(17)        # raises Literal::TypeError (17 not in 18..)

n = Name.new("Joel")
n.length           # => 4 (because we delegated)
n.upcase           # NoMethodError (not delegated)
```

### Auto-aliases for known supertypes

`Literal::Value(t)` checks `subtype?` against common types and aliases the obvious "to" method to `value`:

| Type subtype of | Alias added |
|---|---|
| `Integer` | `to_i` |
| `String` | `to_s` and `to_str` |
| `Array` | `to_a` and `to_ary` |
| `Hash` | `to_h` |
| `Float` | `to_f` |
| `Set` | `to_set` |

So `UserID(Integer).new(5).to_i` works without any `delegate` call.

### `delegate(*methods)` (class-level)

Adds explicit pass-through methods to the inner value:

```ruby
Email = Literal::Value(String) do
  delegate :length, :downcase
end
Email.new("joel@drapper.me").length     # => 15
```

This generates a method per name that does `@value.method_name(...)`.

### Subclassing for behaviour

You can subclass directly with `class Foo < Literal::Value(t)` to add domain methods:

```ruby
class Email < Literal::Value(String)
  delegate :length

  def domain
    value.split("@").last
  end
end

email = Email.new("joel@drapper.me")
email.domain     # => "drapper.me"
email.length     # => 15
email.to_s       # => "joel@drapper.me"  (auto-alias)

Email === email  # true
String === email # FALSE - it's *not* a String, even though it wraps one
```

That last point matters: a `Literal::Value(String)` is *not* a `String`. Pass `email.to_s` (or `value`) when you need an actual `String`.

### `.[]`, `.to_proc`, equality

```ruby
UserID[123]                   # same as UserID.new(123)
[1, 2, 3].map(&UserID)        # to_proc returns ->(v) { new(v) }
UserID.new(1) == UserID.new(1)  # true (compares wrapped value)
```

### Marshal / pack

`Literal::Value` instances are marshallable and support `as_pack` / `from_pack` (preserving frozen state).

## `Literal::Delegator(type)`

Same idea as `Value`, but the wrapper inherits from `SimpleDelegator`, so *every* method on the inner value is automatically exposed:

```ruby
UserID = Literal::Delegator(String) do
  def double = length * 2
end

uid = UserID.new("123")
uid.length    # => 3 (delegated)
uid.upcase    # => "123" (delegated)
uid.double    # => 6 (custom)
UserID === uid       # true
```

The wrapper is frozen, equality compares the wrapped object via `__getobj__`.

## Choosing between Value and Delegator

Pick **Value** when:

- The inner value's full method surface would leak the wrong abstraction. (`Email#chars` is probably nonsense.)
- You want the `Email`/`String` distinction to be enforced - the wrapper does *not* `===` as the inner type.
- You'll explicitly delegate the few methods that make sense.

Pick **Delegator** when:

- You want a typed, lightly-augmented version of the inner type with *all* its methods available transparently.
- You don't mind that callers can do `user_id.upcase` and similar - it's a string with a brand.

In both cases the underlying value is type-checked at construction, the instance is frozen, and `===`/`==` compare the wrapped value.
