# Common Patterns

## Nil Safety Patterns

### Safe Navigation with Narrowing

```ruby
class Order
  # @rbs @customer: Customer?

  #: () -> String?
  def customer_name
    # &. establishes non-nil for subsequent access
    if @customer&.active?
      @customer.name  # @customer is Customer here
    end
  end
end
```

### Early Return Pattern

```ruby
class Processor
  # Prefer specific value types over untyped when the structure is known
  # @rbs @data: Hash[String, String | Integer | bool]?

  #: () -> Hash[String, String | Integer | bool]
  def process!
    unless data = @data
      return {}
    end
    # data is Hash for rest of method
    transform(data)
  end
end
```

## Collection Patterns

### Type-Safe Enumeration with Overloads

```ruby
class TodoList
  # @rbs @items: Array[Todo]

  # Overloaded for block/no-block
  #: () -> Enumerator[Todo, void]
  #: () { (Todo) -> void } -> void
  def each(&block)
    return enum_for(:each) unless block
    @items.each(&block)
  end

  # Using boolish for predicates
  #: () { (Todo) -> boolish } -> Array[Todo]
  def select(&block)
    @items.select(&block)
  end
end
```

### Safe Hash Access

```ruby
class Registry
  # @rbs @items: Hash[Symbol, Item]

  #: (Symbol) -> Item?
  def get(key)
    @items[key]
  end

  #: (Symbol) -> Item
  def fetch!(key)
    if item = @items[key]
      item
    else
      raise KeyError, "Not found: #{key}"
    end
  end
end
```

## Module Mixin Patterns

When a module expects methods from including classes or other mixins:

```ruby
# rbs_inline: enabled

module PathParam
  # Declare interface: method provided by including class
  # @rbs!
  #   def encoded_id: () -> String?

  #: () -> String
  def to_param
    encoded_id || raise("Missing encoded_id")
  end
end

class User
  include PathParam

  #: () -> String?
  def encoded_id
    @encoded_id
  end
end
```

## Data and Struct

Ruby's `Data` and `Struct` need explicit RBS:

```ruby
# Ruby
Measure = Data.define(:amount, :unit)

# To avoid type errors, use inheritance pattern:
class Measure < Data.define(:amount, :unit)
end
```

```rbs
# RBS
class Measure
  attr_reader amount: Integer
  attr_reader unit: String

  def initialize: (Integer amount, String unit) -> void
                | (amount: Integer, unit: String) -> void
end
```

## Gradual Typing Strategy

**Key principle:** Avoid `untyped` wherever possible. When adding types gradually, still aim for concrete types—just prioritize which code to type first.

### Phase 1: Public APIs

```ruby
class UserService
  #: (Integer) -> User?
  def find_user(id)
    User.find_by(id: id)
  end

  # Even for "later" methods, add types when you can infer them
  #: (User, Array[Action]) -> Result
  def complex_logic(user, history)
    # Implementation
  end
end
```

### Phase 2: Critical Paths

Focus on business-critical code:

```ruby
class PaymentProcessor
  #: (amount: Integer, currency: String) -> Payment
  def charge(amount:, currency:)
    validate_amount!(amount)
    process_payment(amount, currency)
  end

  private

  #: (Integer) -> void
  def validate_amount!(amount)
    raise "Invalid" if amount <= 0
  end
end
```

### Phase 3: Extract Typed Modules

Pull typed code into modules:

```ruby
module TypedValidations
  #: (String) -> bool
  def valid_email?(email)
    email.match?(/@/)
  end
end

class User
  include TypedValidations
end
```
