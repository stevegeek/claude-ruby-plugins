# Test file for known gotchas and edge cases

class Gotchas
  # 2 ** Integer returns Numeric, not Integer
  def power_of_two(n)
    2 ** n
  end

  # Splat on nilable array - Ruby accepts *nil, Steep doesn't
  def call_with_args(args)
    some_method(*args) if args
  end

  def some_method(*args)
    args.join(", ")
  end

  # Array splat on nilable
  def safe_splat(items)
    some_method(*(items || []))
  end
end
