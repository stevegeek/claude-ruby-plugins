# Troubleshooting and gotchas


## Gotchas and Troubleshooting

### `Cannot find type definitions for library: stringio (0)`

If you encounter this error when running `steep check`:

```
Cannot find type definitions for library: stringio (0)
```

**Solution:** Update your gems and rbs collection:

```bash
bundle update
bundle exec rbs collection update
```


### Instance Variables Don't Narrow

Steep's flow analysis doesn't narrow instance variable types after nil checks. Even when you've checked `if @user`, Steep still treats `@user` as potentially nil inside the block. Assign to a local variable to help Steep understand the narrowing:

```ruby
# WRONG - @user stays User? in if body
if @user
  @user.name  # ERROR: @user is still User?
end

# RIGHT - Assignment narrows type
if user = @user
  user.name   # OK: user is User
end

# Also works with unless/raise
raise "No user" unless user = @user
user.name  # OK: user is User
```

### Splat on Nilable Arrays

Ruby accepts `*nil` (calls `to_a`, returns `[]`), but Steep doesn't:

```ruby
# @rbs @items: Array[String]?

# WRONG - Steep expects Array, not Array?
method_call(*@items)  # ERROR

# RIGHT - Handle nil explicitly
method_call(*(items = @items) ? items : [])

# Or use compact/to_a pattern
method_call(*(@items || []))
```

### Generic Types and `.nil?`

Generic type parameters don't have a `.nil?` method:

```ruby
# @rbs generic T
class Optional
  # @rbs @value: T?

  # WRONG - T doesn't have nil? method
  def present?
    !@value.nil?  # ERROR
  end

  # RIGHT - Use assignment pattern
  def present?
    if value = @value
      true
    else
      false
    end
  end
end
```

### Generic Types Can't Be Raised

Unconstrained generic type parameters can't be used with `raise`:

```ruby
# @rbs generic T
# @rbs generic E
class Result
  # @rbs @error: E?

  # WRONG - E is not constrained to String/Exception
  def unwrap
    raise @error if @error  # ERROR: E can't be raised
    @value
  end
end

# RIGHT - Use String for error type, or constrain E
# @rbs generic T
class Result
  # @rbs @error: String?

  def unwrap
    if err = @error
      raise err  # OK: String can be raised
    end
    @value or raise "No value"
  end
end
```

### Returning `self` With Different Generic Parameters

When a method transforms generic types, you can't return `self` - you must construct a new instance:

```ruby
# @rbs generic T
class Result
  # WRONG - self is Result[T], not Result[U]
  # @rbs [U] () { (T) -> U } -> Result[U]
  def map(&block)
    if value = @value
      Result.ok(yield(value))
    else
      self  # ERROR: Result[T] not compatible with Result[U]
    end
  end

  # RIGHT - Construct new instance explicitly
  def map(&block)
    if value = @value
      Result.ok(yield(value))
    else
      Result.new(nil, @error)  # OK: Creates Result[U]
    end
  end
end
```

### Class Method Generics Must Redeclare Type Parameters

Class methods need their own generic declarations - they don't inherit from the class:

```ruby
# @rbs generic T
class Result
  # WRONG - T from class isn't available in self.ok
  #: (T) -> Result[T]
  def self.ok(value)
    Result.new(value, nil)
  end

  # RIGHT - Redeclare T for the class method
  # @rbs [T] (T) -> Result[T]
  def self.ok(value)
    Result.new(value, nil)
  end
end
```

### Optional Block Syntax Position

The `?` for optional blocks goes before the brace, not after the return type:

```ruby
# WRONG
# @rbs &block: (String) -> void?

# RIGHT
# @rbs &block: ?(String) -> void
```

### `block_given?` Doesn't Narrow

Steep doesn't understand `block_given?` for type narrowing:

```ruby
# WRONG - block still nullable after check
def each(&block)
  return enum_for(:each) unless block_given?
  yield "test"  # ERROR: block might be nil
end

# RIGHT - Check the block variable directly
def each(&block)
  return enum_for(:each) unless block
  yield "test"  # OK
end
```

### Exponentiation Returns Numeric

`2 ** n` returns `Numeric` in Ruby's type system, not `Integer`:

```ruby
#: (Integer) -> Integer
def power_of_two(n)
  2 ** n  # ERROR: returns Numeric, not Integer
end

# RIGHT - Use Numeric return type
#: (Integer) -> Numeric
def power_of_two(n)
  2 ** n
end

# OR - Cast if you know it's Integer
#: (Integer) -> Integer
def power_of_two(n)
  (2 ** n).to_i
end
```

### Return Type with Early Returns

Ensure all code paths match the return type:

```ruby
# WRONG - implicit nil return doesn't match String
#: (Integer) -> String
def fetch(id)
  return "found" if id > 0
  # Falls through to implicit nil - ERROR
end

# RIGHT - All paths return String
#: (Integer) -> String
def fetch(id)
  return "found" if id > 0
  "not found"
end

# OR - Update return type to allow nil
#: (Integer) -> String?
def fetch(id)
  return "found" if id > 0
end
```

### Forgetting the Magic Comment

Inline RBS annotations are silently ignored without the magic comment:

```ruby
# WRONG - No types generated
class User
  attr_reader :name #: String
end

# RIGHT
# rbs_inline: enabled
class User
  attr_reader :name #: String
end
```

### Substring Slicing Returns Optional

`String#[]` with a range always returns `String?`, even when you've verified the string length:

```ruby
# WRONG - Steep doesn't track string length
if arg.start_with?("--")
  rest = arg[2..].split("=", 2)  # ERROR: arg[2..] is String?
end

# RIGHT - Handle nil explicitly
if arg.start_with?("--")
  rest = arg[2..] or next
  parts = rest.split("=", 2)
end
```

### Array Indexing Returns Optional

Array element access always returns the optional type `T?`, not `T`:

```ruby
# WRONG - parts[0] is String?, not String
parts = str.split("=", 2)
key = parts[0]     # key is String?
options[key] = v   # ERROR: can't use String? as Hash key

# RIGHT - Guard against nil
parts = str.split("=", 2)
key = parts[0] or next false
options[key] = v   # OK: key is String
```

### `_Each` Interface vs Array/Enumerable

The `_Each` interface only provides the `each` method. Use `Array` or `Enumerable` when you need other collection methods:

```ruby
# WRONG - _Each doesn't have to_a
# @rbs items: _Each[Item]
def format(items)
  items.to_a.each { }  # ERROR: _Each doesn't have to_a
end

# RIGHT - Use Array or Enumerable
# @rbs items: Array[Item]
def format(items)
  items.each { }  # OK
end
```

### Empty Collections Need Type Annotations in Strict Mode

In strict mode (`D::Ruby.strict`), empty `{}` and `[]` require type annotations. Even with standalone RBS files, you need inline comments for empty collections:

```ruby
# WRONG - Steep can't infer type of empty collection
options = {}

# RIGHT - Annotate empty collections
options = {} #: Hash[String, String]
items = [] #: Array[Item]
```

This creates a hybrid approach even when using standalone RBS files. To avoid this, use `D::Ruby.default` instead of strict mode.

### Enumerable Requires Type Parameter

When including `Enumerable`, specify what type it yields:

```ruby
# WRONG - Missing type parameter
class List
  include Enumerable  # ERROR in RBS
end

# RIGHT - Specify element type
class List
  include Enumerable[Item]
end
```

### Union Types in Method Signatures Need Parentheses

When using union types as return types with overloading:

```rbs
# WRONG - Ambiguous parsing
def parse: (String) -> String | Integer

# RIGHT - Parenthesize union return types
def parse: (String) -> (String | Integer)
```

### Top-Level Type Aliases Pollute Namespace

Type aliases at the top level are global:

```ruby
# WRONG - Pollutes global namespace
type user_id = Integer

# RIGHT - Scope to module/class
class MyApp
  type user_id = Integer
end
```

### Multiple Signature Directories Cause Duplicate Errors

When using multiple `signature` calls in Steepfile with relative paths, Steep may load the same files with different path representations (relative vs absolute), causing `DuplicatedDeclarationError`:

```ruby
# Steepfile

# WRONG - Relative paths can cause duplicate declaration errors
target :app do
  check "lib"
  signature "sig/generated"
  signature "sig/patches"
end

# RIGHT - Use File.expand_path for consistent absolute paths
target :app do
  check "lib"
  signature File.expand_path("sig/generated", __dir__)
  signature File.expand_path("sig/patches", __dir__)
end
```

This happens because Steep loads signatures differently during initialization vs. on file changes, and relative paths can appear as two different paths for the same file.
