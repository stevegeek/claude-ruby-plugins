# Rails integration

When `Rails` is defined at load time, Literal auto-loads `literal/railtie.rb`. The Railtie registers ActiveModel/ActiveRecord types and patches `ActiveRecord` for relation typing. The type registrations are guarded by `defined?(::ActiveModel::Type)` and the AR-specific ones additionally by `defined?(::ActiveRecord::Type)`, so they no-op gracefully if those parts of Rails aren't loaded.

The integration files live in `lib/literal/rails/` and are conditionally loaded depending on which Rails components are present.

## ActiveModel attribute types

Two `ActiveModel::Type` subclasses are registered:

- `:literal_enum` — wraps a `Literal::Enum`. Stores the enum's `value` in the database; reads back via `Enum.coerce(value)`.
- `:literal_flags` — wraps a `Literal::Flags*` subclass. Stores as a bit-string (`to_bit_string`); reads back via `from_bit_string`.

Use them with `attribute`:

```ruby
class Order < ApplicationRecord
  class Status < Literal::Enum(Integer)
    Pending = new(1)
    Paid = new(2)
    Shipped = new(3)
  end

  class Toggles < Literal::Flags8
    define(rush: 0, gift_wrapped: 1, signature_required: 2)
  end

  attribute :status, :literal_enum, type: Status
  attribute :toggles, :literal_flags, type: Toggles
end

order = Order.new(status: 1, toggles: "00000011")
order.status        # => Order::Status::Pending
order.toggles       # => Order::Toggles instance with rush + gift_wrapped on
```

`cast` handles incoming values (integer, symbol, or already-an-enum); `serialize` and `deserialize` move to/from the DB.

The same registrations are also added to `ActiveRecord::Type` when `ActiveRecord` is present.

## ActiveRecord relation typing

`literal/rails.rb` patches `ActiveRecord` with a top-level method `ActiveRecord.Relation(ModelClass)` that returns a Literal type matcher for relations. So you can `prop` an AR relation:

```ruby
class Recommendations < Literal::Object
  prop :users, ActiveRecord.Relation(User)
end
```

The matcher accepts:

- `ActiveRecord::Relation`
- `ActiveRecord::Associations::CollectionProxy`
- `ActiveRecord::AssociationRelation`

…provided their `model` is `ModelClass` or a subclass.

`inspect` returns `ActiveRecord::Relation(User)`.

## ActiveJob serializer for enums

`Literal::Rails::EnumSerializer < ActiveJob::Serializers::ObjectSerializer` lets you pass `Literal::Enum` members as ActiveJob arguments. Register it in your initializer if you need it:

```ruby
# config/initializers/literal.rb
Rails.application.config.active_job.custom_serializers << Literal::Rails::EnumSerializer
```

The inner payload is `[version, class_name, value]` (passed via `super(payload)`, so ActiveJob wraps it in its own envelope on the wire). On deserialise, `class_name.constantize[value]` looks the member up by its underlying value.

## Boundaries

The Rails plugin is intentionally narrow. Notable things it *doesn't* do:

- It doesn't replace `ActiveRecord`'s type system or schema introspection.
- It doesn't auto-coerce on assignment of arbitrary props (use `coerce` blocks on `prop` for that).
- There's no validations integration - if you want Literal types to drive AR validations, you wire that up yourself in `validate :…`.
