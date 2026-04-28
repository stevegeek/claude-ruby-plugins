# `Literal::Struct` and `Literal::Data`

These are two ready-made base classes built on `Literal::Properties` for the most common case: structured objects with typed fields. They differ only in mutability and equality semantics.

## At a glance

| | `Literal::Struct` | `Literal::Data` |
|---|---|---|
| Mutability | Mutable (writers default `:public`) | Immutable - instances are frozen |
| `prop` default `reader` | `:public` | `:public` |
| `prop` default `writer` | `:public` | `false` (no writers) |
| Equality | Identity-aware: structs of same class with same props are `==` | Same |
| Hash key | Yes (uses class hash) | Yes |
| `Marshal` / `as_pack` / `from_pack` | Yes | Yes |
| `[]` / `[]=` accessors | Both | Only `[]` (read) |
| `Klass.define(name: String)` | No | Yes - inline class definition |
| Use when | You want named, typed fields and may mutate them later | You want a value-shaped record (think: Ruby's `Data.define`, but typed) |

Both inherit from `Literal::DataStructure`, which provides:

- `to_h` / `to_hash` (alias)
- `deconstruct` (returns values in declaration order)
- `deconstruct_keys(keys)` (returns the hash, optionally filtered)
- `[](key)` (Symbol or String) - reads via property name
- Marshal compatibility (`marshal_dump` / `marshal_load`)
- `as_pack` / `from_pack` for snapshot/restore

## `Literal::Struct`

```ruby
class Person < Literal::Struct
  prop :name, String
end

p = Person.new(name: "Joel")
p.name           # => "Joel"
p.name = "Jill"  # writer is public by default
p.to_h           # => { name: "Jill" }
p[:name]         # => "Jill" (also accepts "name")
p[:name] = "Bob" # writer via []=
```

Struct exposes `[]=` that takes a Symbol or String key (any other type raises `TypeError`).

Equality: two structs of the same class with the same `to_h` are `==`. Subclasses are *not* equal to their parent even with matching props (test/struct.test.rb confirms this).

```ruby
a = Person.new(name: "Joel")
b = Student.new(name: "Joel", final_grade: 90)  # Student < Person
a == b   # => false
```

## `Literal::Data`

```ruby
class Person < Literal::Data
  prop :name, String
end

p = Person.new(name: "Joel")
p.frozen?              # => true
p[:name]               # => "Joel"
p == Person.new(name: "Joel")   # => true
```

Notable extras Data adds beyond Struct:

- **Frozen by default**: `data.frozen?` is true. No writer methods are generated. The instance is frozen at the end of `initialize` (via `Literal::Properties::DataSchema`); property *values* are not deep-frozen by Literal - they're only frozen if you (or `frozen_string_literal: true`) made them frozen.
- **Inline define**: `Literal::Data.define(name: String, age: Integer)` returns an anonymous Data class with those props.
- **Hash coercion**: a Data instance is implicitly coercible to a Hash (it `to_h`s when passed to `merge`).
- **Better hashing**: equality and hash are derived from props, so two Data instances with the same fields are usable as the same hash key.

```ruby
PersonOnTheFly = Literal::Data.define(name: String)
PersonOnTheFly.new(name: "John").to_h    # => { name: "John" }

p1 = Person.new(name: "John")
{ last: "Doe" }.merge(p1)                # => { last: "Doe", name: "John" }
```

Since instances are frozen, you'll typically construct a new Data when you need a "change":

```ruby
p2 = Person.new(**p1.to_h, name: "Jack")
```

There's no built-in `with` method; use the splat pattern.

## When to pick Struct vs Data

- Use **Data** by default for record-shaped values: API responses, view-models, query parameters, anything you treat as immutable.
- Use **Struct** when you need to mutate fields after construction - e.g., builders, accumulating state.
- Use plain **`Literal::Object`** (just `extend Literal::Properties`) when you want richer behaviour (private writers, custom methods) without the data/struct conventions.

## Pattern matching

Both support `case/in`:

```ruby
case person
in Person(name: "Joel")
  ...
in { name: String => name }
  ...
end
```

`deconstruct_keys` is implemented, so keyword patterns Just Work.

## Marshal / pack

```ruby
class RootStruct < Literal::Struct
  prop :name, String
end

data = RootStruct.new(name: "Joel")
restored = Marshal.load(Marshal.dump(data))
# Or via the explicit pack interface (avoids Marshal):
restored = RootStruct.from_pack(data.as_pack)
```

Note: marshalling needs a *named* class. Anonymous classes (`Class.new(Literal::Struct)`) won't round-trip.

## Empty data

Empty Data classes work, hash to themselves, and are equal to other instances of *the same* class but not to other empty Data classes.

```ruby
class Empty < Literal::Data; end
Empty.new == Empty.new                                # true
Empty.new == Class.new(Literal::Data).new            # false
```
