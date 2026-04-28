# `Literal::Flags` - bitfield flags

`Literal::Flags` packs a fixed set of named boolean flags into a single integer. Useful for compact storage (DB column, cookie, network protocol) and quick set operations.

There are four sizes: `Literal::Flags8`, `Flags16`, `Flags32`, `Flags64` - pick the smallest one your bit count fits in. Each class sets `BYTES`, `BITS`, and `PACKER` (a `Array#pack` directive: `"C"`, `"S"`, `"L"`, `"Q"`).

## Defining a flags class

```ruby
class Style < Literal::Flags8
  define(
    bold: 0,
    italic: 1,
    underlined: 2,
  )
end
```

Each name maps to a *bit position* (not a bit mask). `define` enforces uniqueness of the bit values and freezes the class. `Style::FLAGS` is the frozen `{ bold: 0, italic: 1, ... }` map.

For each named flag, a predicate `bold?`/`italic?`/`underlined?` is generated.

## Constructing

```ruby
Style.new(italic: true, underlined: true)   # by named flags
Style.new(0b00000110)                       # by raw integer
Style.from_array([false]*7 + [true])        # by bit array (MSB first; length must match BITS)
Style.from_bit_string("00000010")           # by binary string
Style.from_tokens([:bold, :italic])         # by symbol list
Style.from_int(value)                       # bypasses kwarg path
Style.unpack(packed_string)                 # from a packed binary using PACKER
```

Instances are frozen.

## Reading

```ruby
flags = Style.new(bold: true, italic: true)

flags.bold?           # => true
flags.underlined?     # => false
flags[:bold]          # => true (Symbol lookup)
flags.value           # => raw integer (e.g. 3)
flags.to_i            # alias of value
flags.to_h            # => { bold: true, italic: true, underlined: false }
flags.to_a            # array of booleans, MSB first, length BITS
flags.to_tokens       # => [:bold, :italic] - only set flags
flags.to_bit_string   # => "00000011"
flags.pack            # binary string (uses PACKER)
flags.inspect         # debug
```

## Updating (immutable)

`with(**changes)` returns a *new* Flags instance. Originals stay unchanged:

```ruby
a = Style.new(italic: true, underlined: true)
b = a.with(bold: true, underlined: false)

a.bold?       # => false
b.bold?       # => true
b.underlined? # => false
```

## Set operations

```ruby
a | b   # union (returns new instance of the same class)
a & b   # intersection
```

Both accept either another Flags instance of the same class or a raw `Integer`.

## Iteration

`Literal::Flags` includes `Enumerable`. `each` yields `[name, bool]` pairs in declaration order:

```ruby
Style.new(bold: true).map.to_a
# => [[:bold, true], [:italic, false], [:underlined, false]]
```

## Pattern matching

```ruby
case flags
in { bold: true, italic: true }
  ...
in [false, false, false, false, false, false, _, _]
  # via deconstruct (to_a)
end
```

`deconstruct_keys` returns the bool hash (optionally filtered by keys).

## When to use vs alternatives

- vs a Hash of booleans - Flags use one Integer in memory and one column in a DB.
- vs Ruby's `Set` of symbols - Flags have a fixed shape, predicates, and packing/unpacking.
- vs `Literal::Enum` - Enum is mutually exclusive members with a typed value; Flags is a *set* of booleans (multiple can be on at once).

The Rails plugin (see `references/rails.md`) provides an `ActiveModel::Type` that stores a Flags value as an integer and casts back to your subclass.
