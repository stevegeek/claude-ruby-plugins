# Generic container class

class Container
  def initialize(value)
    @value = value
  end

  def get
    @value
  end

  def map(&block)
    Container.new(yield(@value))
  end

  def or_else(default)
    if value = @value
      value
    else
      default
    end
  end
end
