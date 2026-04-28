# `Literal::Enum` - typed, indexed, ordered enumerations

`Literal::Enum(type)` is a class factory: subclass it, declare constants with `new(value, **props)`, and you get a frozen, ordered, indexable enumeration whose members all share a typed `value`. Plus auto-generated predicates, lookup tables (indexes), pattern-match support, and Comparable.

## Basic shape

```ruby
class Color < Literal::Enum(Integer)
  prop :hex, String

  index :hex, String
  index :lower_hex, String, unique: false do |color|
    color.hex.downcase
  end

  Red = new(1, hex: "#FF0000")
  Green = new(2, hex: "#00FF00")
  Blue = new(3, hex: "#0000FF")
  SPRING_GREEN = new(4, hex: "#00FF7F")

  __after_defined__ if RUBY_ENGINE == "truffleruby"
end
```

What that gives you:

- `Color::Red`, `Color::Green`, etc. are `Color` instances, frozen, with `value` of type `Integer`.
- `Color::Red.value` => `1`. `Color::Red.hex` => `"#FF0000"` (extra `prop`s are public readers, no writers).
- Predicate methods auto-derived from the constant name: `Color::Red.red?`, `Color::SPRING_GREEN.spring_green?`. The CamelCase/SHOUTY name is converted to snake-case + `?`.
- `Color` itself is `Enumerable` over its members.
- The class is frozen after definition; you can't add members later.

`__after_defined__` is auto-called via `TracePoint` when the class definition ends. On TruffleRuby (no equivalent TracePoint behaviour) you must call it explicitly, as shown.

## Member type

`Literal::Enum(type)` makes the *value* type required-positional:

```ruby
class Switch < Literal::Enum(_Boolean)
  On = new(true) do
    def toggle = Off
  end

  Off = new(false) do
    def toggle = On
  end
end
```

Each `new` accepts an optional block that's `instance_exec`'d on the new member - useful for adding member-specific methods (Switch's `toggle` is a classic).

The value of each member must be unique - reusing a value raises `ArgumentError`.

## Lookup APIs

```ruby
Color[1]               # => Color::Red (lookup by value, nil if absent)
Color.cast(1)          # alias of [] (returns nil if absent)
Color.fetch(1)         # raises KeyError on miss
Color.coerce(1)        # by value
Color.coerce(:Red)     # by constant name (Symbol)
Color.coerce(Color::Red) # idempotent
```

`coerce` is what you usually want; it's also `Color.to_proc`'s body, so you can do:

```ruby
[1, :Green, Color::Blue].map(&Color)
# => [Color::Red, Color::Green, Color::Blue]
```

`coerce` raises `ArgumentError` if the value/symbol can't be resolved.

## Indexes

Define a named index that builds a hash from member -> the indexed key. By default, indexes are unique (`fetch` returns the single member); pass `unique: false` for multi-value buckets.

```ruby
class Color < Literal::Enum(Integer)
  prop :hex, String
  index :hex, String                           # unique by default
  index :lower_hex, String, unique: false, &:hex # block extracts the key
  ...
end

Color.where(hex: "#FF0000")        # => [Color::Red]   (always returns array-like bucket)
Color.find_by(hex: "#FF0000")      # => Color::Red    (only on unique indexes)
```

Index keys are *type-checked* against the index's declared type (e.g. `String`); `where(hex: 123)` raises `Literal::TypeError`.

`find_by` raises `ArgumentError` on a non-unique index.

## Position / ordering

Members keep their declaration order; each carries a `__position__` field:

```ruby
Color.position_of(Color::Red)    # => 0
Color.position_of(:Red)          # => 0
Color.position_of(1)             # => 0  (by value)
Color.at_position(0)             # => Color::Red

Color::Red <=> Color::Green      # => -1 (Comparable, so < > <= >= work)
Color::Red.succ                  # => Color::Green
Color::SPRING_GREEN.succ         # => nil (last member)
Color::Red.pred                  # => nil
```

Because `Comparable` is mixed in via `<=>`, ranges work too: `(Color::Red..Color::Green)` is a `Range`.

## Iteration / collection helpers

```ruby
Color.each { |c| ... }
Color.to_a                       # array of members in order
Color.to_set                     # Set of members
Color.to_h                       # { Color::Red => 1, Color::Green => 2, Color::Blue => 3, ... } - keys are member objects
Color.to_h { |m| [m.value, m] }  # custom shape
Color.values                     # all values
Color.names                      # member -> constant name hash
Color.members                    # array of members (alias for to_a)
```

## Inspection / serialisation

```ruby
Color::Red.to_sym       # => :Red
Color::Red.to_s         # => "Red"
Color::Red.name         # => "Color::Red" (or "Outer::Color::Red")
Color::Red.inspect      # => "Color::Red"
```

`Marshal.dump(Color::Red)` serialises the member's *value*; `Marshal.load` re-resolves to the canonical member via `[]`.

## Pattern matching

Enum supports both positional and keyword patterns:

```ruby
case color
in Color[1]               # match by value (positional)
  ...
in Color[hex: "#FF0000"]  # match by attribute (keyword)
  ...
in Color                  # match any Color
  ...
end
```

`deconstruct` is `[value]`; `deconstruct_keys` is `to_h`.

## Comparison with Ruby's stdlib

Compared to plain Ruby:

- vs `Module#const_set` constants - Literal::Enum gives you a closed set, ordering, indexes, predicates, type checks, all in one.
- vs `Data.define` - Literal::Enum constrains *which* instances exist; you can't construct extras after the class freezes.
- vs `ActiveRecord::Enum` - similar idea, but here it's a Ruby concept independent of any DB. There's a Rails integration (`references/rails.md`) that maps a Literal::Enum onto an ActiveModel attribute.
