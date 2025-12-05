# Module mixin pattern with interface methods

module Formattable
  def format
    "[#{format_type}] #{format_content}"
  end
end

class TextFormatter
  include Formattable

  attr_reader :text

  def initialize(text)
    @text = text
  end

  def format_type
    "TEXT"
  end

  def format_content
    @text.strip
  end
end

class NumberFormatter
  include Formattable

  attr_reader :number, :precision

  def initialize(number, precision = 2)
    @number = number
    @precision = precision
  end

  def format_type
    "NUMBER"
  end

  def format_content
    @number.round(@precision).to_s
  end
end
