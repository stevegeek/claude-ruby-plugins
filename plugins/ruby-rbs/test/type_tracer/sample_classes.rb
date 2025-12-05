# frozen_string_literal: true

# Sample classes for testing TypeTracer
# Each class demonstrates different typing scenarios

module TestSamples
  # Basic class with primitives
  class Calculator
    def add(a, b)
      a + b
    end

    def divide(a, b)
      return nil if b == 0
      a.to_f / b
    end

    def self.pi
      3.14159
    end
  end

  # Class with optional/nilable returns
  class UserFinder
    def initialize
      @users = { 1 => "Alice", 2 => "Bob" }
    end

    def find(id)
      @users[id]
    end

    def find!(id)
      @users.fetch(id)
    end

    def find_all(ids)
      ids.map { |id| @users[id] }.compact
    end
  end

  # Class with various collection types
  class Collections
    def array_of_strings
      ["a", "b", "c"]
    end

    def array_of_mixed
      [1, "two", :three]
    end

    def hash_simple
      { name: "test", count: 42 }
    end

    def hash_nested
      { user: { name: "Alice", tags: [:admin, :active] } }
    end

    def empty_array
      []
    end

    def empty_hash
      {}
    end

    def set_example
      require "set"
      Set.new([1, 2, 3])
    end

    def range_example
      1..10
    end
  end

  # Class with blocks
  class Transformer
    def map_values(items, &block)
      items.map(&block)
    end

    def each_with_index(items)
      return enum_for(:each_with_index, items) unless block_given?
      items.each_with_index { |item, i| yield(item, i) }
    end
  end

  # Class demonstrating keyword args
  class Formatter
    def format(text, width: 80, align: :left, truncate: false)
      result = text.to_s
      result = result[0, width] if truncate && result.length > width
      result
    end
  end

  # Class with exceptions
  class Validator
    def validate!(value)
      raise ArgumentError, "nil not allowed" if value.nil?
      raise TypeError, "must be string" unless value.is_a?(String)
      value
    end

    def safe_validate(value)
      validate!(value)
    rescue StandardError
      nil
    end
  end

  # Struct for testing
  Person = Struct.new(:name, :age)

  # Class with special types
  class SpecialTypes
    def regexp_match(text)
      text.match(/\d+/)
    end

    def time_now
      Time.now
    end

    def symbol_list
      [:foo, :bar, :baz]
    end

    def proc_example
      ->(x) { x * 2 }
    end

    def struct_example
      Person.new("Alice", 30)
    end
  end

  # Class methods vs instance methods
  class Counter
    @@count = 0

    def self.increment
      @@count += 1
    end

    def self.current
      @@count
    end

    def self.reset
      @@count = 0
    end

    def instance_count
      @@count
    end
  end
end
