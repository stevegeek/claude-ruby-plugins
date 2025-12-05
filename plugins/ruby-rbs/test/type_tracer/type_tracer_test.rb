# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "set"
require_relative "../../scripts/type_tracer"
require_relative "sample_classes"

class TypeTracerTest < Minitest::Test
  def setup
    @tracer = TypeTracer.new(class_pattern: /TestSamples/)
  end

  # === Basic Type Detection ===

  def test_integer_types
    @tracer.trace do
      calc = TestSamples::Calculator.new
      calc.add(1, 2)
    end

    obs = @tracer.observations
    assert obs.key?("TestSamples::Calculator#add")
    assert_includes_arg_type obs, "TestSamples::Calculator#add", "Integer"
  end

  def test_float_return
    @tracer.trace do
      calc = TestSamples::Calculator.new
      calc.divide(10, 4)
    end

    obs = @tracer.observations
    assert obs.key?("TestSamples::Calculator#divide")
    returns = obs["TestSamples::Calculator#divide"][:returns]
    assert returns.include?("Float"), "Expected Float return, got: #{returns.inspect}"
  end

  def test_nil_return_tracked
    @tracer.trace do
      calc = TestSamples::Calculator.new
      calc.divide(10, 0)  # Returns nil
    end

    obs = @tracer.observations
    returns = obs["TestSamples::Calculator#divide"][:returns]
    assert returns.include?("nil"), "Expected nil return to be tracked, got: #{returns.inspect}"
  end

  def test_class_method
    @tracer.trace do
      TestSamples::Calculator.pi
    end

    obs = @tracer.observations
    assert obs.key?("TestSamples::Calculator.pi"), "Expected class method with . notation"
  end

  # === Optional/Nilable Returns ===

  def test_method_returning_nil_sometimes
    @tracer.trace do
      finder = TestSamples::UserFinder.new
      finder.find(1)   # Returns "Alice"
      finder.find(999) # Returns nil
    end

    obs = @tracer.observations
    returns = obs["TestSamples::UserFinder#find"][:returns]
    assert returns.include?("String"), "Expected String return"
    assert returns.include?("nil"), "Expected nil return for missing key"
  end

  # === Collection Types ===

  def test_array_of_strings
    @tracer.trace do
      TestSamples::Collections.new.array_of_strings
    end

    obs = @tracer.observations
    returns = obs["TestSamples::Collections#array_of_strings"][:returns]
    assert returns.any? { |r| r.include?("Array") && r.include?("String") }
  end

  def test_array_of_mixed_types
    @tracer.trace do
      TestSamples::Collections.new.array_of_mixed
    end

    obs = @tracer.observations
    returns = obs["TestSamples::Collections#array_of_mixed"][:returns]
    ret = returns.first
    assert ret.include?("Array"), "Expected Array type"
    assert ret.include?("Integer"), "Expected Integer in union"
    assert ret.include?("String"), "Expected String in union"
    assert ret.include?("Symbol"), "Expected Symbol in union"
  end

  def test_empty_array
    @tracer.trace do
      TestSamples::Collections.new.empty_array
    end

    obs = @tracer.observations
    returns = obs["TestSamples::Collections#empty_array"][:returns]
    assert returns.any? { |r| r.include?("Array") }
  end

  def test_hash_with_symbol_keys
    @tracer.trace do
      TestSamples::Collections.new.hash_simple
    end

    obs = @tracer.observations
    returns = obs["TestSamples::Collections#hash_simple"][:returns]
    ret = returns.first
    assert ret.include?("Hash"), "Expected Hash type"
    assert ret.include?("Symbol"), "Expected Symbol keys"
  end

  def test_set_type
    @tracer.trace do
      TestSamples::Collections.new.set_example
    end

    obs = @tracer.observations
    returns = obs["TestSamples::Collections#set_example"][:returns]
    assert returns.any? { |r| r.include?("Set") }
  end

  def test_range_type
    @tracer.trace do
      TestSamples::Collections.new.range_example
    end

    obs = @tracer.observations
    returns = obs["TestSamples::Collections#range_example"][:returns]
    assert returns.any? { |r| r.include?("Range") }
  end

  # === Special Types ===

  def test_regexp_match_result
    @tracer.trace do
      TestSamples::SpecialTypes.new.regexp_match("abc123")
    end

    obs = @tracer.observations
    returns = obs["TestSamples::SpecialTypes#regexp_match"][:returns]
    assert returns.any? { |r| r.include?("MatchData") }
  end

  def test_time_type
    @tracer.trace do
      TestSamples::SpecialTypes.new.time_now
    end

    obs = @tracer.observations
    returns = obs["TestSamples::SpecialTypes#time_now"][:returns]
    assert returns.include?("Time")
  end

  def test_proc_type
    @tracer.trace do
      TestSamples::SpecialTypes.new.proc_example
    end

    obs = @tracer.observations
    returns = obs["TestSamples::SpecialTypes#proc_example"][:returns]
    assert returns.include?("Proc")
  end

  def test_struct_type
    @tracer.trace do
      TestSamples::SpecialTypes.new.struct_example
    end

    obs = @tracer.observations
    returns = obs["TestSamples::SpecialTypes#struct_example"][:returns]
    assert returns.any? { |r| r.include?("Person") || r.include?("Struct") }
  end

  # === Keyword Arguments ===

  def test_keyword_args_captured
    @tracer.trace do
      TestSamples::Formatter.new.format("hello", width: 40, align: :center)
    end

    obs = @tracer.observations
    args = obs["TestSamples::Formatter#format"][:args]
    assert args.any? { |a| a.any? { |param| param.include?("width") } }
  end

  # === Exception Handling ===

  def test_exception_doesnt_corrupt_stack
    @tracer.trace do
      validator = TestSamples::Validator.new
      begin
        validator.validate!(nil)
      rescue ArgumentError
        # Expected
      end
      validator.safe_validate("ok")
    end

    obs = @tracer.observations
    assert obs.key?("TestSamples::Validator#safe_validate")
  end

  def test_exceptions_recorded
    @tracer.trace do
      validator = TestSamples::Validator.new
      begin
        validator.validate!(nil)
      rescue ArgumentError
        # Expected
      end
    end

    obs = @tracer.observations
    exceptions = obs["TestSamples::Validator#validate!"][:exceptions]
    assert exceptions.any? { |e| e.include?("ArgumentError") }
  end

  # === JSON Output ===

  def test_to_json_output
    @tracer.trace do
      calc = TestSamples::Calculator.new
      calc.add(1, 2)
    end

    json = @tracer.to_json
    parsed = JSON.parse(json)

    assert parsed.is_a?(Hash)
    assert parsed.key?("TestSamples::Calculator#add")
    method_data = parsed["TestSamples::Calculator#add"]
    assert method_data.key?("args")
    assert method_data.key?("returns")
    assert method_data.key?("returns_nil")
  end

  private

  def assert_includes_arg_type(observations, method_key, type_name)
    args = observations[method_key][:args]
    found = args.any? { |arg_set| arg_set.any? { |arg| arg.include?(type_name) } }
    assert found, "Expected #{type_name} in args for #{method_key}, got: #{args.inspect}"
  end
end
