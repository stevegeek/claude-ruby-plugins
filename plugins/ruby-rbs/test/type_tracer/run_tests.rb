#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone test runner that avoids minitest plugin conflicts

require "json"
require "set"
require_relative "../../scripts/type_tracer"
require_relative "sample_classes"

class SimpleTestRunner
  def initialize
    @passed = 0
    @failed = 0
    @errors = []
  end

  def assert(condition, message = "Assertion failed")
    if condition
      @passed += 1
      print "."
    else
      @failed += 1
      @errors << message
      print "F"
    end
  end

  def assert_includes(collection, item, message = nil)
    msg = message || "Expected #{collection.inspect} to include #{item.inspect}"
    assert(collection.include?(item), msg)
  end

  def assert_any(collection, message = nil, &block)
    msg = message || "Expected collection to have matching element"
    assert(collection.any?(&block), msg)
  end

  def report
    puts
    puts
    if @errors.any?
      puts "Failures:"
      @errors.each_with_index { |e, i| puts "  #{i + 1}. #{e}" }
      puts
    end
    puts "#{@passed + @failed} tests, #{@passed} passed, #{@failed} failed"
    @failed == 0
  end
end

runner = SimpleTestRunner.new

# === Basic Type Detection ===

puts "Testing basic type detection..."

# Test integer types
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  calc = TestSamples::Calculator.new
  calc.add(1, 2)
end
obs = tracer.observations
runner.assert(obs.key?("TestSamples::Calculator#add"), "Should track Calculator#add")
args = obs["TestSamples::Calculator#add"][:args].flatten
runner.assert(args.any? { |a| a.include?("Integer") }, "Should detect Integer args")

# Test float return
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Calculator.new.divide(10, 4)
end
obs = tracer.observations
returns = obs["TestSamples::Calculator#divide"][:returns]
runner.assert(returns.include?("Float"), "divide should return Float")

# Test nil return tracked
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Calculator.new.divide(10, 0)
end
obs = tracer.observations
returns = obs["TestSamples::Calculator#divide"][:returns]
runner.assert(returns.include?("nil"), "divide(x, 0) should return nil")

# Test class method
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Calculator.pi
end
obs = tracer.observations
runner.assert(obs.key?("TestSamples::Calculator.pi"), "Should use . for class methods")

# === Optional/Nilable Returns ===

puts "\nTesting nilable returns..."

tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  finder = TestSamples::UserFinder.new
  finder.find(1)   # Returns "Alice"
  finder.find(999) # Returns nil
end
obs = tracer.observations
returns = obs["TestSamples::UserFinder#find"][:returns]
runner.assert(returns.include?("String"), "find should return String sometimes")
runner.assert(returns.include?("nil"), "find should return nil sometimes")

# === Collection Types ===

puts "\nTesting collection types..."

# Array of strings
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Collections.new.array_of_strings
end
obs = tracer.observations
returns = obs["TestSamples::Collections#array_of_strings"][:returns]
runner.assert_any(returns, "Should return Array[String]") { |r| r.include?("Array") && r.include?("String") }

# Mixed array
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Collections.new.array_of_mixed
end
obs = tracer.observations
ret = obs["TestSamples::Collections#array_of_mixed"][:returns].first
runner.assert(ret.include?("Array"), "Should be Array")
runner.assert(ret.include?("Integer"), "Should include Integer")
runner.assert(ret.include?("String"), "Should include String")
runner.assert(ret.include?("Symbol"), "Should include Symbol")

# Empty array
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Collections.new.empty_array
end
obs = tracer.observations
returns = obs["TestSamples::Collections#empty_array"][:returns]
runner.assert_any(returns, "Empty array should be Array[untyped]") { |r| r.include?("Array") }

# Hash
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Collections.new.hash_simple
end
obs = tracer.observations
ret = obs["TestSamples::Collections#hash_simple"][:returns].first
runner.assert(ret.include?("Hash"), "Should be Hash")
runner.assert(ret.include?("Symbol"), "Should have Symbol keys")

# Set
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Collections.new.set_example
end
obs = tracer.observations
returns = obs["TestSamples::Collections#set_example"][:returns]
runner.assert_any(returns, "Should detect Set") { |r| r.include?("Set") }

# Range
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Collections.new.range_example
end
obs = tracer.observations
returns = obs["TestSamples::Collections#range_example"][:returns]
runner.assert_any(returns, "Should detect Range") { |r| r.include?("Range") }

# === Special Types ===

puts "\nTesting special types..."

# MatchData
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::SpecialTypes.new.regexp_match("abc123")
end
obs = tracer.observations
returns = obs["TestSamples::SpecialTypes#regexp_match"][:returns]
runner.assert_any(returns, "Should detect MatchData") { |r| r.include?("MatchData") }

# Time
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::SpecialTypes.new.time_now
end
obs = tracer.observations
returns = obs["TestSamples::SpecialTypes#time_now"][:returns]
runner.assert(returns.include?("Time"), "Should detect Time")

# Proc
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::SpecialTypes.new.proc_example
end
obs = tracer.observations
returns = obs["TestSamples::SpecialTypes#proc_example"][:returns]
runner.assert(returns.include?("Proc"), "Should detect Proc")

# Struct
tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::SpecialTypes.new.struct_example
end
obs = tracer.observations
returns = obs["TestSamples::SpecialTypes#struct_example"][:returns]
runner.assert_any(returns, "Should detect Struct class") { |r| r.include?("Person") }

# === Keyword Arguments ===

puts "\nTesting keyword arguments..."

tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Formatter.new.format("hello", width: 40, align: :center)
end
obs = tracer.observations
args = obs["TestSamples::Formatter#format"][:args]
runner.assert_any(args, "Should capture keyword args") { |a| a.any? { |p| p.include?("width") && p.include?("[keyword]") } }

# === Exception Handling ===

puts "\nTesting exception handling..."

tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  validator = TestSamples::Validator.new
  begin
    validator.validate!(nil)
  rescue ArgumentError
    # Expected
  end
  validator.safe_validate("ok")
end
obs = tracer.observations
runner.assert(obs.key?("TestSamples::Validator#safe_validate"), "Should track methods after exceptions")
# Check exceptions were recorded
exceptions = obs["TestSamples::Validator#validate!"][:exceptions]
runner.assert_any(exceptions, "Should record exceptions") { |e| e.include?("ArgumentError") }

# === JSON Output ===

puts "\nTesting JSON output..."

tracer = TypeTracer.new(class_pattern: /TestSamples/)
tracer.trace do
  TestSamples::Calculator.new.add(1, 2)
end
json = tracer.to_json
parsed = JSON.parse(json)
runner.assert(parsed.is_a?(Hash), "JSON should parse to Hash")
runner.assert(parsed.key?("TestSamples::Calculator#add"), "Should have method key")
method_data = parsed["TestSamples::Calculator#add"]
runner.assert(method_data.key?("args"), "Should have args key")
runner.assert(method_data.key?("returns"), "Should have returns key")
runner.assert(method_data.key?("returns_nil"), "Should have returns_nil flag")

# === Report ===

success = runner.report
exit(success ? 0 : 1)
