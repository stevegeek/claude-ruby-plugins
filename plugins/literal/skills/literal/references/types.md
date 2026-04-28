# Literal type matchers (`Literal::Types`)

`Literal::Types` is a module of methods (named `_Foo`) that build runtime type matchers. To use them in a class, `extend Literal::Types` (or `include` for instance use). `Literal::Properties` already includes `Literal::Types` for you, so any class that does `extend Literal::Properties` can use `_Foo` directly inside the class body.

```ruby
class User
  extend Literal::Properties     # also includes Literal::Types
  prop :tags, _Array(Symbol)
end
```

A "type" in Literal is anything responding to `===`. Plain Ruby `String`, `Integer`, `1..10`, `/regex/`, lambdas, all qualify. The `_Foo` matchers below are *additional* type constructors for common composition needs that primitive `===` doesn't cover (or covers awkwardly).

Every matcher with a question-mark variant (e.g. `_Array?`) is the nilable version, equivalent to `_Nilable(_Array(...))`.

## Cheatsheet

| Constructor | Matches | Notes |
|---|---|---|
| `_Any` | any value *except* `nil` | use to allow anything but require presence |
| `_Any?` / `_Void` | any value including `nil` | accepts everything |
| `_Never` | never matches | bottom type |
| `_Nilable(t)` | `nil` or `t` | shorthand for `_Union(nil, t)` |
| `_Union(a, b, c, ...)` | matches *any* of the types | flattens nested unions; primitives like `nil`/`true`/Symbols are stored efficiently |
| `_Intersection(a, b, ...)` | matches *all* given types | |
| `_Not(t)` or `_Not(a, b)` | does *not* match the type(s) | multi-arg = `_Not(_Union(a, b))` |
| `_TaggedUnion(name: t, age: u)` | a value matching one of the tagged members; can ask `tag_for(value)` | useful for serialisation; merges nested tagged unions |
| `_Boolean` / `_Boolean?` | `true` or `false` (and `nil` for `?`) | |
| `_Truthy` | anything that isn't `nil` or `false` | |
| `_Falsy` | `nil` or `false` | |
| `_Class(K)` | `K` itself or a subclass of `K` (the *class*, not an instance) | use `K` (without `_Class`) to match instances |
| `_Descendant(K)` | a *strict* descendant of `K` | excludes `K` itself |
| `_Kind(t)` | recursively kind-matches a type | used by serialisation to walk type structure |
| `_Constraint(K, *a, **k)` | instance of `K` plus extra constraints, e.g. `_Constraint(Array, size: 1..3)` | each kwarg is matched against `obj.public_send(key)` via `===` |
| `_Integer(...)` / `_Float(...)` / `_String(...)` / `_Symbol(...)` / `_Time(...)` / `_Date(...)` | `_Constraint(K, ...)` shortcuts | use bare `Integer` etc. when you don't need a constraint |
| `_Array(t)` | a Ruby `Array` whose every element matches `t` | does *not* return a Literal::Array - this is just a type matcher |
| `_Set(t)` | a Ruby `Set` whose every element matches `t` | |
| `_Hash(k, v)` | a Ruby `Hash` with key/value types | |
| `_Tuple(a, b, c, ...)` | a Ruby `Array` of fixed size with positional types | |
| `_Map(name: String, age: Integer)` | a `Hash` with the exact given keys+types | unlike `_Hash`, cares about which keys must be present |
| `_Range(t)` | a `Range` of `t` | |
| `_Enumerable(t)` | any `Enumerable` whose elements match `t` | |
| `_Interface(:foo, :bar)` | duck type - responds to all methods | structural typing |
| `_Callable` / `_Procable` / `_Lambda` | `_Interface(:call)` / `_Interface(:to_proc)` / `Proc` with `lambda? == true` | |
| `_Frozen(t)` | a frozen object also matching `t` | |
| `_SameObject(obj)` | exact identity, like `equal?` | |
| `_Pattern(/regex/) { |captures| ... }` | regex match where the block must return truthy | block called with `match.captures` and named captures as kwargs |
| `_Predicate("message") { |v| ... }` | arbitrary predicate; `message` shows in errors | recursive defaults to `:reject` |
| `_JSONData` | the value is valid JSON-shaped data | useful when validating parsed JSON |
| `_Deferred { _Class(SomeFutureConstant) }` | block evaluated lazily | use when the type references constants that aren't defined yet (autoload, circular refs) |

## Examples

```ruby
include Literal::Types

# Compose
_Array(_Nilable(Integer))                  # Array<Integer | nil>
_Hash(Symbol, _Union(String, Integer))     # { key: Symbol, value: String|Integer }
_Tuple(String, Integer, Integer)           # exactly 3 elements with these types
_Map(name: String, age: Integer)           # exactly these keys

# Constraints
_Integer(18..127)                          # Integer in 18..127
_String(size: 1..)                         # non-empty string
_Constraint(Array, size: 1..3)             # 1-3 items
_Time((Time.now)..)                        # Time in the future

# Tagged union (used for serialisation)
type = _TaggedUnion(person: Person, note: String)
type.tag_for(Person.new(...))   # => :person
type.tag_for("hi")              # => :note
type.resolve("hi")              # => [:note, String]

# Pattern with captures
date_like = _Pattern(/(\d{4})-(\d{2})-(\d{2})/) do |year, month, day|
  year.to_i.between?(1900, 2100)
end

# Deferred for circular references
class Tree
  extend Literal::Properties
  prop :children, _Array(_Deferred { Tree }), default: -> { [] }
end
```

## Subtype relationships

`Literal.subtype?(t, u)` answers "is every value of `t` also a value of `u`?". Many matchers also implement `>=` / `<=` directly. This is what powers exhaustiveness checks in `Result#handle`, the `Literal::Array#narrow` API, and `_Constraint` hierarchy checks.

```ruby
Literal.subtype?(Integer, Numeric)                     # true
Literal.subtype?(_Array(Integer), _Array(Numeric))     # true (covariant)
Literal.subtype?(_Constraint(Array, size: 1..2), _Constraint(Array, size: 1..5))  # true
```

## Error messages

When a Literal type check fails, you get a `Literal::TypeError` with a structured, indented message that walks into nested types. For example, an `_Array(_Map(person: Person, role: Symbol))` mismatch shows the failing index and the failing key.

```
Type mismatch

User#initialize (from .../my_file.rb:12)
  members
    [0]
      [:role]
        Expected: Symbol
        Actual (Integer): 1
```

The path is built from `Context#fill_receiver` and `Context#add_child` in `Literal::TypeError::Context`, so custom types can integrate into this output by responding to `record_literal_type_errors(context)`.

## Common gotchas

- `_Class(K)` matches the *class object* `K` and its subclasses, not an instance of `K`. To match an instance, just use `K` directly.
- `_Array(t)` is a type matcher, not a container. It says "this Hash/value/property is a `::Array` with elements of `t`". For a typed container (with type-checked mutation), see `Literal::Array(t)` in `collections.md`.
- `_Map` requires *exactly* the given keys; extra keys cause failure. Use `_Hash` when keys are open.
- Everything is checked at runtime, on assignment/initialisation. There's no static checker, no compile step.
- Many Literal classes `freeze` themselves, including `Value` and `DataStructure`-based classes. Don't try to mutate them.
