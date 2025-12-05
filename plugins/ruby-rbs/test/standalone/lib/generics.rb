# Comprehensive generics test file

# Simple generic box/wrapper
class Box
  def initialize(value)
    @value = value
  end

  def get
    @value
  end

  def set(value)
    @value = value
  end

  # Method-level generic: transform contents
  def map(&block)
    Box.new(yield(@value))
  end
end

# Result monad for error handling
# Note: Using String for error type to avoid generic type constraints
class Result
  def initialize(value, error)
    @value = value
    @error = error
  end

  def self.ok(value)
    Result.new(value, nil)
  end

  def self.err(error)
    Result.new(nil, error)
  end

  # Use assignment pattern - generic types don't have .nil? method
  def ok?
    if _err = @error
      false
    else
      true
    end
  end

  def err?
    if _err = @error
      true
    else
      false
    end
  end

  def unwrap
    if err = @error
      raise err
    end
    # Return value - Steep needs explicit type assertion for T
    @value or raise "No value"
  end

  def unwrap_or(default)
    if value = @value
      value
    else
      default
    end
  end

  # Transform success value
  def map(&block)
    if value = @value
      Result.ok(yield(value))
    else
      Result.new(nil, @error)
    end
  end

  # Chain operations that might fail
  def and_then(&block)
    if value = @value
      yield(value)
    else
      Result.new(nil, @error)
    end
  end
end

# Generic stack collection
class Stack
  def initialize
    @items = []
  end

  def push(item)
    @items.push(item)
    self
  end

  def pop
    @items.pop
  end

  def peek
    @items.last
  end

  def empty?
    @items.empty?
  end

  def size
    @items.size
  end

  def each(&block)
    return enum_for(:each) unless block
    @items.each(&block)
  end

  def to_a
    @items.dup
  end
end

# Generic pair/tuple
class Pair
  attr_reader :first, :second

  def initialize(first, second)
    @first = first
    @second = second
  end

  def swap
    Pair.new(@second, @first)
  end

  def map_first(&block)
    Pair.new(yield(@first), @second)
  end

  def map_second(&block)
    Pair.new(@first, yield(@second))
  end

  def to_a
    [@first, @second]
  end
end

# Generic cache with key-value types
class Cache
  def initialize
    @store = {}
  end

  def get(key)
    @store[key]
  end

  def set(key, value)
    @store[key] = value
  end

  def fetch(key, &block)
    if value = @store[key]
      value
    else
      @store[key] = yield
    end
  end

  def delete(key)
    @store.delete(key)
  end

  def keys
    @store.keys
  end

  def values
    @store.values
  end

  def size
    @store.size
  end
end
