# frozen_string_literal: true

require "set"
require "json"

# Runtime type tracer that instruments method calls and records observed types.
#
# Uses TracePoint to capture method calls and returns, recording argument types
# and return types. Outputs observations that can help inform RBS signatures.
#
# Usage:
#   tracer = TypeTracer.new(target_pattern: /MyApp/)
#   tracer.trace { run_my_code }
#   puts tracer.to_json
#
# CLI:
#   ruby scripts/type_tracer.rb --pattern 'MyApp' script.rb
#
class TypeTracer
  attr_reader :observations

  # Initialize the tracer with optional filters.
  #
  # @param target_pattern [Regexp, nil] Pattern to match file paths
  # @param class_pattern [Regexp, nil] Pattern to match class/module names
  #
  # At least one pattern should be provided to avoid tracing everything.
  # If both are provided, either matching will include the method.
  def initialize(target_pattern: nil, class_pattern: nil)
    @target_pattern = target_pattern
    @class_pattern = class_pattern
    # Default to matching everything if no pattern provided (not recommended)
    @match_all = @target_pattern.nil? && @class_pattern.nil?
    @observations = Hash.new { |h, k| h[k] = { args: [], returns: Set.new, exceptions: Set.new } }
    @call_stack = []
  end

  def trace(&block)
    call_trace = TracePoint.new(:call) do |tp|
      next unless should_trace?(tp)

      method_key = method_key_for(tp)
      arg_types = capture_arg_types(tp)

      @observations[method_key][:args] << arg_types unless arg_types.empty?
      @call_stack.push({ key: method_key, path: tp.path, lineno: tp.lineno })
    end

    return_trace = TracePoint.new(:return) do |tp|
      next unless should_trace?(tp)

      # Find matching call in stack (handles exceptions that skip returns)
      call_info = pop_matching_call(tp)
      next unless call_info

      return_type = type_name(tp.return_value)
      @observations[call_info[:key]][:returns] << return_type
    end

    # Track exceptions to avoid stack corruption
    raise_trace = TracePoint.new(:raise) do |tp|
      next unless should_trace?(tp)
      next if @call_stack.empty?

      # Record that an exception occurred (don't pop - :return may still fire)
      current = @call_stack.last
      if current
        exception_type = tp.raised_exception.class.name
        @observations[current[:key]][:exceptions] << exception_type
      end
    end

    call_trace.enable
    return_trace.enable
    raise_trace.enable

    begin
      block.call
    ensure
      call_trace.disable
      return_trace.disable
      raise_trace.disable
    end
  end

  def report
    puts "# Type observations from runtime tracing"
    puts "# Format: Class#method(arg_types) -> return_types"
    puts

    @observations.keys.sort.each do |method_key|
      data = @observations[method_key]
      report_method(method_key, data)
    end
  end

  def to_json(*_args)
    result = {}
    @observations.each do |method_key, data|
      result[method_key] = {
        "args" => data[:args],
        "returns" => data[:returns].to_a.sort,
        "returns_nil" => data[:returns].include?("nil"),
        "exceptions" => data[:exceptions].to_a.sort
      }
    end
    JSON.pretty_generate(result)
  end

  def to_h
    result = {}
    @observations.each do |method_key, data|
      result[method_key] = {
        args: data[:args],
        returns: data[:returns].to_a,
        returns_nil: data[:returns].include?("nil"),
        exceptions: data[:exceptions].to_a
      }
    end
    result
  end

  private

  def should_trace?(tp)
    return true if @match_all

    # Check file path pattern
    if @target_pattern && tp.path
      return true if tp.path.match?(@target_pattern)
    end

    # Check class/module name pattern
    if @class_pattern && tp.defined_class
      class_name = tp.defined_class.to_s
      return true if class_name.match?(@class_pattern)
    end

    false
  end

  def pop_matching_call(tp)
    # Pop from stack, but verify it matches (handles exception-caused mismatches)
    return nil if @call_stack.empty?

    expected_key = method_key_for(tp)

    # Try to find matching call (may not be at top due to exceptions)
    idx = @call_stack.rindex { |c| c[:key] == expected_key }
    return nil unless idx

    @call_stack.delete_at(idx)
  end

  def method_key_for(tp)
    receiver = tp.self
    method_name = tp.method_id

    case receiver
    when Class, Module
      "#{receiver.name || receiver.inspect}.#{method_name}"
    else
      "#{receiver.class.name || receiver.class.inspect}##{method_name}"
    end
  end

  def capture_arg_types(tp)
    return [] unless tp.binding

    begin
      method = tp.self.method(tp.method_id)
      params = method.parameters
    rescue NameError
      return []
    end

    args = []
    params.each do |kind, name|
      next unless name

      begin
        value = tp.binding.local_variable_get(name)
        type = type_name(value)

        # Include parameter kind for better context
        case kind
        when :key, :keyreq, :keyrest
          args << "#{name}: #{type} [keyword]"
        when :rest
          args << "*#{name}: #{type}"
        when :block
          args << "&#{name}: #{type}"
        else
          args << "#{name}: #{type}"
        end
      rescue NameError
        # Parameter not available in binding
      end
    end

    args
  end

  def type_name(value)
    case value
    when nil
      "nil"
    when true, false
      "bool"
    when Integer
      "Integer"
    when Float
      "Float"
    when String
      "String"
    when Symbol
      "Symbol"
    when Regexp
      "Regexp"
    when Range
      element_type = value.begin ? type_name(value.begin) : "untyped"
      "Range[#{element_type}]"
    when Time
      "Time"
    when defined?(Date) && Date
      "Date"
    when defined?(DateTime) && DateTime
      "DateTime"
    when MatchData
      "MatchData"
    when Array
      array_type(value)
    when Hash
      hash_type(value)
    when Set
      set_type(value)
    when Struct
      struct_type(value)
    when defined?(Data) && Data
      data_type(value)
    when Class
      "singleton(#{value.name || 'Class'})"
    when Module
      "singleton(#{value.name || 'Module'})"
    when Proc
      "Proc"
    when Method, UnboundMethod
      "Method"
    when Enumerator
      "Enumerator[untyped, untyped]"
    when IO, File
      value.class.name
    when Exception
      value.class.name
    else
      value.class.name || "Object"
    end
  end

  def array_type(value)
    if value.empty?
      "Array[untyped]"
    else
      element_types = value.map { |v| type_name(v) }.uniq
      if element_types.size == 1
        "Array[#{element_types.first}]"
      else
        "Array[#{element_types.sort.join(" | ")}]"
      end
    end
  end

  def hash_type(value)
    if value.empty?
      "Hash[untyped, untyped]"
    else
      key_types = value.keys.map { |k| type_name(k) }.uniq
      val_types = value.values.map { |v| type_name(v) }.uniq

      key_str = key_types.size == 1 ? key_types.first : key_types.sort.join(" | ")
      val_str = val_types.size == 1 ? val_types.first : val_types.sort.join(" | ")

      "Hash[#{key_str}, #{val_str}]"
    end
  end

  def set_type(value)
    if value.empty?
      "Set[untyped]"
    else
      element_types = value.map { |v| type_name(v) }.uniq
      if element_types.size == 1
        "Set[#{element_types.first}]"
      else
        "Set[#{element_types.sort.join(" | ")}]"
      end
    end
  end

  def struct_type(value)
    # Return the actual struct class name if available
    value.class.name || "Struct"
  end

  def data_type(value)
    # Ruby 3.2+ Data class
    value.class.name || "Data"
  end

  def report_method(method_key, data)
    arg_signatures = data[:args].map { |args| args.join(", ") }.uniq
    return_types = data[:returns].to_a.sort
    exceptions = data[:exceptions].to_a.sort

    # Format return type, noting if nil is possible
    returns_str = if return_types.empty?
      "void"
    elsif return_types == ["nil"]
      "nil"
    else
      non_nil = return_types - ["nil"]
      if return_types.include?("nil") && non_nil.size == 1
        "#{non_nil.first}?"  # Use optional syntax
      else
        return_types.join(" | ")
      end
    end

    arg_signatures.each do |args|
      line = "#{method_key}(#{args}) -> #{returns_str}"
      line += "  # raises: #{exceptions.join(", ")}" unless exceptions.empty?
      puts line
    end

    # If no args were captured but returns were
    if arg_signatures.empty? && !return_types.empty?
      line = "#{method_key}() -> #{returns_str}"
      line += "  # raises: #{exceptions.join(", ")}" unless exceptions.empty?
      puts line
    end
  end
end

# CLI interface
if __FILE__ == $0
  require "optparse"

  options = {
    file_pattern: nil,
    class_pattern: nil,
    format: "text"
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby #{$0} [options] <script.rb> [-- script_args...]"

    opts.on("-p", "--path-pattern PATTERN", "Regex pattern to match file paths") do |p|
      options[:file_pattern] = Regexp.new(p)
    end

    opts.on("-c", "--class-pattern PATTERN", "Regex pattern to match class/module names") do |c|
      options[:class_pattern] = Regexp.new(c)
    end

    opts.on("-f", "--format FORMAT", %w[text json], "Output format: text, json (default: text)") do |f|
      options[:format] = f
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      puts
      puts "At least one pattern (-p or -c) is recommended to filter results."
      puts
      puts "Examples:"
      puts "  # Match by class name"
      puts "  ruby #{$0} -c 'MyApp::' script.rb"
      puts
      puts "  # Match by file path"
      puts "  ruby #{$0} -p 'lib/my_app' script.rb"
      puts
      puts "  # Output as JSON"
      puts "  ruby #{$0} -c 'User' -f json script.rb > types.json"
      puts
      puts "  # Match both patterns (OR logic)"
      puts "  ruby #{$0} -p 'lib/' -c 'MyModule' script.rb"
      exit
    end
  end

  begin
    parser.parse!
  rescue OptionParser::InvalidOption => e
    warn e.message
    warn parser.banner
    exit 1
  end

  if ARGV.empty?
    warn "Error: No script specified"
    warn parser.banner
    exit 1
  end

  script = ARGV.shift

  unless File.exist?(script)
    warn "Error: File not found: #{script}"
    exit 1
  end

  if options[:file_pattern].nil? && options[:class_pattern].nil?
    warn "Warning: No pattern specified. This will trace ALL method calls and may be slow."
    warn "Consider using -c 'YourClass' or -p 'your/path' to filter."
    warn
  end

  tracer = TypeTracer.new(
    target_pattern: options[:file_pattern],
    class_pattern: options[:class_pattern]
  )

  tracer.trace do
    load script
  end

  case options[:format]
  when "json"
    puts tracer.to_json
  else
    puts
    tracer.report
  end
end
