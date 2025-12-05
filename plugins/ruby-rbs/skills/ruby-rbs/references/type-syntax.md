# Complete Type Syntax Reference

## Primitive Types

| Type | Description |
|------|-------------|
| `String` | String instance |
| `Integer` | Integer instance |
| `Float` | Float instance |
| `Numeric` | Integer \| Float \| Rational \| Complex |
| `Symbol` | Symbol instance |
| `bool` | `true \| false` |
| `boolish` | Any truthy/falsy value (alias of `top`) |
| `nil` | nil value |
| `void` | Return value should not be used |
| `untyped` | Skip type checking |
| `top` | Supertype of all types |
| `bot` | Subtype of all types (never returns) |
| `self` | Type of receiver |
| `instance` | Instance type of the class |
| `class` | Singleton class type |

## Literal Types

```rbs
123                 # Integer literal
3.14                # Float literal
"hello"             # String literal
:symbol             # Symbol literal
true                # Boolean literal
false               # Boolean literal
```

## Optional Types

```rbs
String?             # Equivalent to String | nil
Integer?            # Equivalent to Integer | nil
Array[String]?      # Equivalent to Array[String] | nil
```

## Union Types

```rbs
String | Integer                    # String or Integer
String | Integer | nil              # String, Integer, or nil
:draft | :published | :archived     # Symbol union (enum-like)
```

## Intersection Types

```rbs
_Reader & _Writer                   # Must satisfy both interfaces
```

Note: `&` has higher precedence than `|`, so `A & B | C` means `(A & B) | C`.

## Collection Types

```rbs
Array[String]                       # Array of Strings
Array[Integer | String]             # Mixed array
Hash[Symbol, Integer]               # Hash with Symbol keys, Integer values
Hash[String, User?]                 # Hash with optional values
Set[String]                         # Set of Strings
Range[Integer]                      # Integer range
Enumerator[String, void]            # Enumerator yielding Strings
```

## Tuple Types

Fixed-size heterogeneous arrays:

```rbs
[]                                  # Empty tuple
[String]                            # 1-element tuple
[Integer, String]                   # 2-element tuple
[Symbol, Integer, Integer]          # 3-element tuple
[String, *Integer]                  # First String, rest Integers
```

## Record Types

Fixed-key heterogeneous hashes:

```rbs
{ id: Integer, name: String }       # Required keys
{ id: Integer, name?: String }      # Optional key (name?)
{ "id" => Integer }                 # String keys
{ id: Integer, **String }           # Known key + rest
```

## Proc Types

```rbs
^() -> void                         # No args, no return
^(Integer) -> String                # One arg
^(String, Integer) -> bool          # Multiple args
^(?String) -> Integer               # Optional arg
^(*String) -> void                  # Rest args
^(name: String) -> User             # Keyword arg
^(?size: Integer) -> void           # Optional keyword
^(**String) -> void                 # Keyword rest
^(Integer) { (String) -> void } -> void  # With block
^(?) -> untyped                     # Untyped parameters
```

## Interface Types

```rbs
_Enumerable[String]                 # Interface with type param
_ToS                                # Simple interface
_Comparable                         # Standard interface
```

Interface names start with `_` (underscore).

## Class Singleton Type

```rbs
singleton(String)                   # The String class object
singleton(Hash)                     # The Hash class object
```

## Type Variables

```rbs
T                                   # Type variable
Elem                                # Descriptive type variable
K, V                                # Key/Value type variables
```

Type variables are scoped to their declaration (class, module, interface, or method).

## Namespaced Types

```rbs
::String                            # Root namespace
ActiveRecord::Base                  # Nested namespace
JSON::t                             # Type alias with namespace
```

## Self Type Binding

For blocks that change `self` (like `instance_eval`):

```rbs
^() [self: String] -> void          # Block where self is String
{ () [self: Config] -> void }       # Block parameter with self binding
```

## Context Restrictions

Some types have contextual limitations:

- `void`: Only as return type or generic parameter
- `self`: Only in self-context (method signatures, attributes)
- `class`/`instance`: Only in classish-context (inside class/module)

## Type Alias Declaration

```rbs
# Simple
type name = String

# Union
type json_primitive = String | Integer | Float | bool | nil

# Recursive
type json_value = json_primitive | Array[json_value] | Hash[String, json_value]

# Generic
type result[T] = { success: true, value: T } | { success: false, error: String }

# With variance
type list[out T] = [T, list[T]] | nil
```

## Use Directive

Import types to avoid fully-qualified names. Place at the top of RBS files:

```rbs
# Import single type
use RBS::TypeName

# Import with alias
use RBS::TypeName as TN

# Import all types from namespace
use RBS::AST::*
```

After importing:

```rbs
use ActiveRecord::Base, ActiveRecord::Relation

class User < Base                    # Instead of ActiveRecord::Base
  def self.active: () -> Relation[User]
end
```

## Annotations

Metadata for declarations, members, and method types. Interpreted by tooling (Steep, rbs test).

### Syntax Variants

```rbs
%a{annotation text}                # Using braces
%a(annotation text)                # Using parentheses
%a[annotation text]                # Using brackets
%a|annotation text|                # Using pipes
%a<annotation text>                # Using angle brackets
```

### Common Annotations

```rbs
# Steep annotations
%a{steep:ignore}                   # Ignore type errors

# RBS test annotations
%a{rbs:test:skip}                  # Skip runtime testing for this method

# Documentation annotations (tooling-dependent)
%a{deprecated}                     # Mark as deprecated
%a{deprecated: "Use #new_method instead"}
```

### Usage Examples

```rbs
class MyClass
  # Skip runtime testing for complex method
  %a{rbs:test:skip} def complex_method: (untyped) -> untyped

  # Annotated method type (annotation applies to following overload)
  def fetch: %a{deprecated} (Integer) -> String?
           | (Integer, String default) -> String
end
```
