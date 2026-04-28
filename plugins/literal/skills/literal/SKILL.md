---
name: literal
description: Comprehensive skill for the Literal Ruby gem (https://literal.fun) by Joel Drapper. Use when writing or reviewing Ruby code that uses Literal - typed properties via `prop`/`prop?`, runtime type matchers `_Array`/`_Union`/`_Map`/etc., structured objects (`Literal::Struct`, `Literal::Data`), value objects (`Literal::Value`, `Literal::Delegator`), enums (`Literal::Enum`), bitfield flags (`Literal::Flags`), generic collections (`Literal::Array(...)`, `Set`, `Hash`, `Tuple`), result monads (`Literal::Result`, `Success`, `Failure`), or JSON-style serialization. Also use when designing typed APIs in plain Ruby without external type checkers.
---

# Literal

Literal is a runtime type system for Ruby. It checks types when objects are constructed and when methods are called - no separate type checker needed. The library also provides building blocks for structured objects (Struct/Data), value objects, enums, flags, generic collections, and result monads.

The gemspec summary captures it: *"Enums, properties, generics, structured objects and runtime type checking."*

- Repo: https://github.com/joeldrapper/literal
- Docs: https://literal.fun
- License: MIT, requires Ruby >= 3.1

## How to use this skill

This skill is organised around the major user-facing features. The top-level features are listed below. When the user is working on a specific feature, load the matching reference file from `references/` for full details. Don't load every reference up-front - they're meant to be consulted as needed.

## Core idea: types are anything that responds to `===`

In Literal, a "type" is just anything that returns true/false from `===`. That includes:

- Plain Ruby classes (`String`, `Integer`, `MyClass`) - via `Module#===` (instance check)
- Ranges (`1..10`) - via `Range#===` (cover check)
- Regexps (`/foo/`) - via `Regexp#===` (match check)
- Procs/lambdas - via `Proc#===` (call check)
- Literal's own type matchers from `Literal::Types` (all prefixed with `_`)
- Any object you define with `===`

This is why every Literal API that accepts a "type" can also accept a primitive class or range.

## Top-level features (and which reference to load)

| Feature | What it is | Reference |
|---|---|---|
| Type matchers (`_Array`, `_Union`, `_Map`, `_Nilable`, `_Constraint`, ...) | The `_*` methods from `Literal::Types` for building runtime types | `references/types.md` |
| `prop` / `prop?` | Typed properties on any class via `extend Literal::Properties` | `references/properties.md` |
| `Literal::Struct` | Mutable structured object with `prop` (writers + readers public by default) | `references/struct-and-data.md` |
| `Literal::Data` | Frozen, immutable structured object with `prop` (reader-only) | `references/struct-and-data.md` |
| `Literal::Value(...)` | Typed value-object wrapper around a single value (e.g. `UserID = Literal::Value(Integer)`) | `references/value-and-delegator.md` |
| `Literal::Delegator(...)` | Typed delegator wrapping a value with full method delegation | `references/value-and-delegator.md` |
| `Literal::Enum(type)` | Closed set of typed members with predicates, indexing, ordering | `references/enum.md` |
| `Literal::Flags8/16/32/64` | Compact bitfield with named flags (boolean attributes) | `references/flags.md` |
| `Literal::Array/Set/Hash/Tuple` generics | Type-checked collection wrappers (`Literal::Array(String)`) | `references/collections.md` |
| `Literal::Result(success_t, failure_t)` | Result monad with `Success`/`Failure`, `try`, `and_then`, `also`, `handle` | `references/result.md` |
| `Literal::SerializationContext` + serializers | JSON-style serialize/deserialize driven by Literal types | `references/serialization.md` |
| `Literal.check`, `Literal.subtype?`, error messages | Programmatic type checking and subtype predicates | `references/runtime-checks.md` |
| Rails integration | `ActiveModel::Type` wrappers for enums and flags, `ActiveRecord::Relation(Model)` matcher | `references/rails.md` |

## Quick example

```ruby
require "literal"

class User < Literal::Data
  # _Nilable, _Array, etc. are already available here:
  # Literal::Data < Literal::DataStructure, which `extend`s Literal::Properties,
  # which `include`s Literal::Types.

  prop :id, Integer
  prop :name, String
  prop :email, _Nilable(String)
  prop :tags, _Array(Symbol), default: -> { [] }
end

user = User.new(id: 1, name: "Alice", tags: [:admin])
# raises Literal::TypeError: id must be Integer, got "1"
User.new(id: "1", name: "Alice")
```

## Conventions Joel uses (from the project's AGENTS.md)

- Never use `is_a?` - prefer `===`, `in`, or `case`/`when`. Literal's whole API is built on `===`.
- Tests use a small custom `test do ... end` DSL (see the gem's `test/`); not RSpec or Minitest's `def test_*`.

## When NOT to use Literal

- You already have a Sorbet/RBS/Steep type system covering the codebase. Literal's runtime checks are duplicative there - though many people happily use both, since runtime checks catch what static checkers can't (e.g. unknown JSON shape).
- Hot inner loops where every method call goes through a type check. Literal is fast but not free; benchmark before adopting in tight loops.

## Reference index

- `references/types.md` - Every `_Type` matcher with examples
- `references/properties.md` - `prop`, `prop?`, kinds, defaults, coercion, predicates, writers, introspection
- `references/struct-and-data.md` - `Literal::Struct` vs `Literal::Data`, when to pick which
- `references/value-and-delegator.md` - `Literal::Value` and `Literal::Delegator` for value objects
- `references/enum.md` - `Literal::Enum` members, indexes, coercion, ordering
- `references/flags.md` - `Literal::Flags8/16/32/64` bitfields
- `references/collections.md` - `Literal::Array`, `Set`, `Hash`, `Tuple` generic collections
- `references/result.md` - `Literal::Result`, `Success`, `Failure`, `handle`, `try`, `and_then`
- `references/serialization.md` - `SerializationContext` and the built-in serializers
- `references/runtime-checks.md` - `Literal.check`, `Literal.subtype?`, type errors, `Brand`
- `references/rails.md` - Rails / ActiveModel / ActiveRecord integration
- `references/patterns.md` - Idioms and gotchas across the library
