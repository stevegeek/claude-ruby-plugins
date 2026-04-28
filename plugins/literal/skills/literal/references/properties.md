# `Literal::Properties` - typed properties on any class

`Literal::Properties` is the heart of the gem. `extend` it onto any class to gain a `prop` DSL that defines initializer parameters, optional readers/writers/predicates, and runtime type checking on construction and assignment.

```ruby
class Person
  extend Literal::Properties

  prop :name, String, :positional, reader: :public
  prop :age, Integer, reader: :public
end

Person.new("Joel", age: 30)        # works
Person.new(1, age: "Joel")         # raises Literal::TypeError
```

`Literal::Object` is a tiny shorthand: `class Foo < Literal::Object` is equivalent to `class Foo; extend Literal::Properties; end`. Use it when you don't need to inherit from anything else.

`Literal::Properties` also `include`s `Literal::Types`, so `_Nilable`, `_Array`, etc. are available inside the class body without further imports.

## `prop` signature

```ruby
prop(
  name,                # Symbol - the property name
  type,                # any === -responder, e.g. String, Integer, _Array(Integer), 1..10
  kind = :keyword,     # :positional, :keyword, :*, :**, :& - how it appears in initializer
  reader: false,       # false | :public | :protected | :private
  writer: false,       # false | :public | :protected | :private
  predicate: false,    # false | :public | :protected | :private (defines `name?`)
  default: nil,        # frozen value or Proc; Proc evaluated in receiver context
  description: nil,    # optional doc string
  &coercion            # optional block: receives raw value, returns coerced value
)
```

Returns the symbol (the property name) so you can chain.

`prop?` is a sugar variant: it appends `Literal::Undefined` to the type union and uses `Literal::Undefined` as the default. This lets you distinguish "not provided" from "provided as nil". Use `prop?` when nil is a meaningful value distinct from absence.

## Kinds

| `kind` | Initializer position | Required by default |
|---|---|---|
| `:positional` | positional arg in declared order | yes (unless type allows nil) |
| `:keyword` (default) | keyword arg | yes (unless type allows nil) |
| `:*` | splat - collects remaining positionals into an Array | optional (defaults to `[]`) |
| `:**` | double splat - collects keyword args into a Hash | optional (defaults to `{}`) |
| `:&` | block parameter | required unless type allows nil |

A property is *optional* if it has an explicit `default:`, OR its type matches `nil` (e.g. `_Nilable(...)`), OR it's a splat. Otherwise the initializer raises `ArgumentError` when the value is missing.

## Defaults

Defaults must be either a frozen value or a `Proc`:

```ruby
prop :tags, _Array(Symbol), default: -> { [] }      # fresh empty array each instance
prop :status, Symbol, default: :pending             # symbols are frozen, fine
prop :name, String, default: "Unknown"              # frozen string literal, fine
prop :pending_at, Time, default: -> { Time.now }    # computed
prop :combined, String, default: -> { "#{hello} #{world}" }  # Procs are evaluated in receiver context, can use other props
```

Trying to use a mutable, unfrozen literal (e.g. `default: []`) raises `Literal::ArgumentError`.

## Readers, writers, predicates

These are off by default - you opt in:

```ruby
prop :name, String, reader: :public                    # `def name`
prop :secret, String, reader: :private                 # private reader
prop :enabled, _Boolean, predicate: :public            # `def enabled?`
prop :counter, Integer, writer: :public                # `def counter=(v)` checks type on assignment
```

The writer also runs the type check, raising `Literal::TypeError` on bad assignment. The predicate is `!!@var`.

`Literal::Struct`'s default for `prop` is `reader: :public, writer: :public`. `Literal::Data`'s default is `reader: :public, writer: false` (immutable). On a plain `extend Literal::Properties` class, the default is `reader: false`.

## Coercion

Pass a block to coerce raw input into the declared type *before* the type check:

```ruby
class Item
  extend Literal::Properties

  prop :name, String, :positional, reader: :public do |raw|
    raw.to_s.strip
  end
end

Item.new(123)   # raw 123 is coerced to "123" before the String type check
```

The block is `instance_exec`d on the receiver during initialisation, so `self` is the new instance under construction. Use this for normalisation, not for accepting wildly different shapes.

## `:class` reserved name

You cannot define a *reader* named `:class` because it would shadow `Object#class` (which Literal itself uses). Storing the property is fine, but `reader: :public` raises.

## After-initialize callback

Define `def after_initialize` (any visibility - public/protected/private all work) and Literal will call it at the end of `initialize`. Useful for invariants that span multiple props.

```ruby
class Range
  extend Literal::Properties
  prop :start, Integer
  prop :stop, Integer

  def after_initialize
    raise ArgumentError, "stop must be >= start" if stop < start
  end
end
```

## Generated initializer

For each `prop`, Literal builds (and recompiles) a custom `initialize` via `module_eval` of generated source. That means:

- The error backtrace points to your file, not to a Literal method.
- `prop` order matters - properties appear in the initializer in the order: `:positional`, `:*`, `:keyword`, `:**`, `:&`. Within the same kind, declaration order wins.
- Each `prop` call re-generates and re-includes the extension module, so adding props later is fine but not free.

## Inheritance

Subclasses inherit `literal_properties` from their parent (it's `dup`'d, not shared). Re-declaring a prop in a subclass overwrites the parent's, e.g. to narrow a type:

```ruby
class Person; extend Literal::Properties
  prop :age, Integer, reader: :public
end

class Friend < Person
  prop :age, Float, reader: :public      # narrowed: now requires Float
end
```

## Introspection

`Klass.literal_properties` returns a `Literal::Properties::Schema` (Enumerable of `Literal::Property` objects). Each property exposes `name`, `type`, `kind`, `reader`, `writer`, `predicate`, `default`, `description`, plus query methods: `keyword?`, `positional?`, `splat?`, `double_splat?`, `block?`, `optional?`, `required?`, `default?`.

Mix in `Literal::Properties::Introspection` for filter helpers:

```ruby
class Person; extend Literal::Properties
  extend Literal::Properties::Introspection
  prop :name, String, :positional
  prop :age, Integer
end

Person.required_keyword_property_names  # => [:age]
Person.positional_property_names         # => [:name]
```

## DocString

Literal includes a `DocString` module with `# @!method initialize(...)` so YARD/RDoc tools can document the auto-generated initializer. No action required - it's just there.

## Common patterns

### A class that's just typed kwargs

Use `Literal::Object`:

```ruby
class CreateUser < Literal::Object
  prop :email, _String(/@/)
  prop :name, _String(size: 1..100)
  prop :role, _Union(:admin, :member, :guest), default: :member
end
```

### Reusing a prop list as schema

```ruby
class Person < Literal::Object
  prop :name, String, reader: :public
  prop :age, Integer, reader: :public
end

# Later, for forms or serialization
Person.literal_properties.each do |prop|
  puts "#{prop.name}: #{prop.type.inspect} (#{prop.required? ? 'required' : 'optional'})"
end
```

### Required vs optional cheatsheet

| Declaration | Required? |
|---|---|
| `prop :x, String` | yes (no default, type doesn't allow nil) |
| `prop :x, _Nilable(String)` | no (nil acceptable) |
| `prop :x, String, default: "hi"` | no |
| `prop :x, _Array(Integer), :*` | no (splat) |
| `prop :x, Proc, :&` | yes |
| `prop :x, _Nilable(Proc), :&` | no |
