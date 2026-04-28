# `Literal::SerializationContext` and serializers

Literal ships a JSON-style serialisation layer that walks a Literal type and turns Ruby values into a JSON-safe shape (and back). It's a la carte: you pick which serializers your context supports, and types are dispatched by which serializer's `kind` matches.

This is *not* a general-purpose JSON encoder. It's a typed encoder driven by the same `Literal::Types` you use elsewhere - `_Array`, `_Hash`, `_Union`, `_TaggedUnion`, `_Set`, `_Nilable`, structs/data, etc.

## Building a context

```ruby
require "literal"

include Literal::Types

Example = Literal::SerializationContext.new(
  Literal::StringSerializer,
  Literal::SymbolSerializer,
  Literal::IntegerSerializer,
  Literal::FloatSerializer,
  Literal::BooleanSerializer,
  Literal::DateSerializer,
  Literal::StructureSerializer,
  Literal::TaggedUnionSerializer,
  Literal::UnionSerializer,
  Literal::HashSerializer,
  Literal::ArraySerializer,
  Literal::SetSerializer,
  Literal::NilableSerializer,
)
```

Each serializer class is instantiated with the context, in order. The context computes:

- `Example.type` - a `_TaggedUnion(...)` of every serializer's tag/type.
- `Example.kind` - a `_Union(...)` of every serializer's `kind`.
- A `tag -> serializer` map for deserialisation.

Tags include `:string`, `:symbol`, `:integer`, `:float`, `:boolean`, `:date`, `:structure`, `:tagged_union`, `:union`, `:hash`, `:array`, `:set`, `:nilable`. Order matters: nilable, union, and tagged_union are sorted toward the end (`type_order` in `serialization_context.rb`) so primitive serializers win first.

## Serialise / deserialise

```ruby
Example.serialize(value, type:, strict: true)
Example.deserialize(value, type:, strict: true)
```

The `type` here can be any Literal type (a class, `_Array(Integer)`, a `Literal::Data` subclass, etc.). The context picks the matching serializer by `kind === type` and delegates.

`strict: true` (default) checks both ends:

- Pre-serialize: the value must match the type.
- Post-serialize: the result must be `_JSONData?`-shaped (recursive JSON-safe).
- Pre-deserialize: the input must be `_JSONData`.
- Post-deserialize: the result must match the type.

Disable with `strict: false` if you need to round-trip values during a recursive walk where the outer call has already validated.

## Implicit (untyped) serialisation

If you pass `type: Example.type` (the entire union of tagged serializers), the encoder writes `[tag, value]` so the deserializer can self-resolve. This is how you serialise heterogeneous data when you don't have a specific Literal type:

```ruby
Example.serialize("hello", type: Example.type)
# => ["string", "hello"]

Example.serialize(Set[1, 2, 3], type: Example.type)
# => ["set", [["integer", 1], ["integer", 2], ["integer", 3]]]
```

Useful for logging, generic envelopes, and audit trails.

## What each serializer produces

| Type | Serialised form |
|---|---|
| `String` | the string itself |
| `Symbol` | string |
| `Integer` / `Float` / `Boolean` | itself |
| `Date` | ISO-8601 string (`"2025-01-13"`) |
| `_Set(t)` | array of serialised elements (set itself becomes an array because JSON has no Set) |
| `_Array(t)` | array of serialised elements |
| `_Hash(k, v)` | hash with stringified keys |
| `_Nilable(t)` | underlying serialisation, or `nil` |
| `_Union(...)` | `[tag, serialized_value]` |
| `_TaggedUnion(name: t, ...)` | `[tag_string, serialized_value]` |
| `Literal::Data` / `Literal::Struct` (`StructureSerializer`) | hash of `{ "prop_name" => serialized_value }` |

Tagged-union output (e.g. `["name", "Joel"]`) is what makes this safe to round-trip even with structurally identical alternatives.

## Round-trip example

```ruby
class Person < Literal::Data
  prop :name, String
  prop :age, Integer
end

class Envelope < Literal::Data
  extend Literal::Types
  prop :id, Integer
  prop :owner, Person
  prop :tags, _Set(Symbol)
  prop :metadata, _Hash(Symbol, _Array(_Nilable(_Union(String, Integer))))
  prop :schedule, _Array(Date)
  prop :choice, _TaggedUnion(person: Person, note: String)
end

original = Envelope.new(
  id: 7,
  owner: Person.new(name: "Joel", age: 42),
  tags: Set[:admin, :staff],
  metadata: { primary: ["active", 1, nil] },
  schedule: [Date.new(2025, 1, 13)],
  choice: Person.new(name: "Jill", age: 40),
)

serialized = Example.serialize(original, type: Envelope)
# => { "id" => 7, "owner" => {...}, ... "choice" => ["person", {...}] }

restored = Example.deserialize(serialized, type: Envelope)
restored == original   # true
```

## Building a custom serializer

Subclass `Literal::Serializer` and define:

- `tag` (Symbol) - unique within the context
- `type` (the Literal type this serializer accepts)
- `kind` (a Literal type like `_Class(SomeBase)` that matches the *kind of type* you handle)
- `serialize(value, type:)`
- `deserialize(value, type:)`

Inside `serialize`/`deserialize`, call `serialize_contents(child_value, type: child_type)` / `deserialize_contents(...)` to recurse through the context for nested types.

Look at `lib/literal/serializers/` in the gem for full examples of each built-in.

## When to use this vs `to_json` / `as_json` / Oj

- Use Literal's serialiser when your data is already shaped via Literal types and you want a *typed* round-trip. The output is normalised (Sets become arrays, Symbols become strings, Dates ISO-formatted) and validated on both ends.
- Use a generic JSON encoder when you don't have a Literal type to dispatch on, or when you only need to emit (not round-trip) and don't care about untyped JSON shape.
