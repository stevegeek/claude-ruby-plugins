#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to compare hand-written RBS files with generated ones from rbs-inline
# Usage: bundle exec ruby scripts/compare_rbs.rb

require "rbs"
require "set"

class RBSComparator
  def initialize(original_path, generated_path, strict_param_names: false)
    @original_path = original_path
    @generated_path = generated_path
    @strict_param_names = strict_param_names
    @differences = []
  end

  def compare
    original_decls = parse_file(@original_path)
    generated_decls = parse_file(@generated_path)

    compare_declarations(original_decls, generated_decls)

    @differences
  end

  private

  def parse_file(path)
    content = File.read(path)
    buffer = RBS::Buffer.new(name: path, content: content)
    _, _, decls = RBS::Parser.parse_signature(buffer)
    decls
  end

  def compare_declarations(original, generated)
    original_by_name = index_declarations(original)
    generated_by_name = index_declarations(generated)

    all_names = (original_by_name.keys + generated_by_name.keys).uniq

    all_names.each do |name|
      orig = original_by_name[name]
      gen = generated_by_name[name]

      if orig.nil?
        @differences << { type: :missing_in_original, name: name, declaration: gen }
      elsif gen.nil?
        @differences << { type: :missing_in_generated, name: name, declaration: orig }
      else
        compare_class_or_module(name, orig, gen)
      end
    end
  end

  def index_declarations(decls)
    decls.each_with_object({}) do |decl, hash|
      case decl
      when RBS::AST::Declarations::Class, RBS::AST::Declarations::Module
        hash[decl.name.to_s] = decl
      end
    end
  end

  def compare_class_or_module(name, orig, gen)
    orig_members = normalize_members(orig.members)
    gen_members = normalize_members(gen.members)

    # Compare includes
    compare_member_set(name, :includes, orig_members[:includes], gen_members[:includes])

    # Compare constants
    compare_member_set(name, :constants, orig_members[:constants], gen_members[:constants])

    # Compare methods
    compare_methods(name, orig_members[:methods], gen_members[:methods])

    # Compare attr_readers/writers
    compare_member_set(name, :attributes, orig_members[:attributes], gen_members[:attributes])

    # Compare instance variables
    compare_member_set(name, :ivars, orig_members[:ivars], gen_members[:ivars])
  end

  def normalize_members(members)
    result = {
      includes: [],
      constants: [],
      methods: {},
      attributes: [],
      ivars: []
    }

    members.each do |member|
      case member
      when RBS::AST::Members::Include
        result[:includes] << member.name.to_s
      when RBS::AST::Declarations::Constant
        result[:constants] << { name: member.name.to_s, type: member.type.to_s }
      when RBS::AST::Members::MethodDefinition
        result[:methods][member.name.to_s] = normalize_method(member)
      when RBS::AST::Members::AttrReader, RBS::AST::Members::AttrWriter, RBS::AST::Members::AttrAccessor
        result[:attributes] << { name: member.name.to_s, type: member.type.to_s, kind: member.class.name.split("::").last }
      when RBS::AST::Members::InstanceVariable
        result[:ivars] << { name: member.name.to_s, type: member.type.to_s }
      end
    end

    result
  end

  def normalize_method(method_def)
    {
      name: method_def.name.to_s,
      kind: method_def.kind,
      overloads: method_def.overloads.map { |o| normalize_overload(o) },
      visibility: method_def.visibility
    }
  end

  def normalize_overload(overload)
    mt = overload.method_type
    {
      params: normalize_params(mt.type),
      return_type: mt.type.return_type.to_s,
      block: mt.block ? normalize_block(mt.block) : nil
    }
  end

  def normalize_params(func_type)
    # When @strict_param_names is false, we ignore parameter names as they are
    # semantically irrelevant - (Object? value) and (Object?) are equivalent
    if @strict_param_names
      {
        required_positionals: func_type.required_positionals.map { |p| { name: p.name&.to_s, type: p.type.to_s } },
        optional_positionals: func_type.optional_positionals.map { |p| { name: p.name&.to_s, type: p.type.to_s } },
        rest_positionals: func_type.rest_positionals&.then { |p| { name: p.name&.to_s, type: p.type.to_s } },
        required_keywords: func_type.required_keywords.transform_values { |p| p.type.to_s },
        optional_keywords: func_type.optional_keywords.transform_values { |p| p.type.to_s },
        rest_keywords: func_type.rest_keywords&.then { |p| { name: p.name&.to_s, type: p.type.to_s } }
      }
    else
      {
        required_positionals: func_type.required_positionals.map { |p| { type: p.type.to_s } },
        optional_positionals: func_type.optional_positionals.map { |p| { type: p.type.to_s } },
        rest_positionals: func_type.rest_positionals&.then { |p| { type: p.type.to_s } },
        required_keywords: func_type.required_keywords.transform_values { |p| p.type.to_s },
        optional_keywords: func_type.optional_keywords.transform_values { |p| p.type.to_s },
        rest_keywords: func_type.rest_keywords&.then { |p| { type: p.type.to_s } }
      }
    end
  end

  def normalize_block(block)
    {
      required: block.required,
      params: normalize_params(block.type),
      return_type: block.type.return_type.to_s
    }
  end

  def compare_member_set(class_name, member_type, orig, gen)
    orig_set = Set.new(orig.map(&:to_s))
    gen_set = Set.new(gen.map(&:to_s))

    (orig_set - gen_set).each do |item|
      @differences << { type: :missing_in_generated, class: class_name, member_type: member_type, item: item }
    end

    (gen_set - orig_set).each do |item|
      @differences << { type: :missing_in_original, class: class_name, member_type: member_type, item: item }
    end
  end

  def compare_methods(class_name, orig_methods, gen_methods)
    all_method_names = (orig_methods.keys + gen_methods.keys).uniq

    all_method_names.each do |method_name|
      orig = orig_methods[method_name]
      gen = gen_methods[method_name]

      if orig.nil?
        @differences << { type: :missing_in_original, class: class_name, member_type: :method, method: method_name }
      elsif gen.nil?
        @differences << { type: :missing_in_generated, class: class_name, member_type: :method, method: method_name }
      elsif orig != gen
        @differences << {
          type: :method_mismatch,
          class: class_name,
          method: method_name,
          original: orig,
          generated: gen
        }
      end
    end
  end
end

def print_usage
  puts <<~USAGE
    Usage: bundle exec ruby #{$PROGRAM_NAME} [OPTIONS] <original_rbs> <generated_rbs>
           bundle exec ruby #{$PROGRAM_NAME} [OPTIONS] --dir <original_dir> <generated_dir>

    Compare RBS signature files to verify consistency between hand-written
    and generated (from rbs-inline) type definitions.

    Arguments:
      <original_rbs>   Path to the original/hand-written .rbs file
      <generated_rbs>  Path to the generated .rbs file to compare against

    Options:
      --dir                  Compare all .rbs files in two directories
      --json                 Output results as JSON (for programmatic use)
      --quiet                Only output on failure (exit code still set)
      --strict-param-names   Treat parameter names as significant (default: false)
      -h, --help             Show this help message

    Examples:
      # Compare two specific files
      bundle exec ruby #{$PROGRAM_NAME} sig/user.rbs sig/generated/user.rbs

      # Compare all files in directories
      bundle exec ruby #{$PROGRAM_NAME} --dir sig/models sig/generated/models

      # JSON output for scripting
      bundle exec ruby #{$PROGRAM_NAME} --json sig/user.rbs sig/generated/user.rbs

    Exit codes:
      0 - All comparisons passed (signatures match)
      1 - Differences found or error occurred
  USAGE
end

def compare_files(original_path, generated_path, options = {})
  unless File.exist?(original_path)
    return { file: original_path, status: :error, message: "Original file not found: #{original_path}" }
  end

  unless File.exist?(generated_path)
    return { file: original_path, status: :missing, message: "Generated file not found: #{generated_path}" }
  end

  comparator = RBSComparator.new(
    original_path,
    generated_path,
    strict_param_names: options[:strict_param_names] || false
  )
  differences = comparator.compare

  if differences.empty?
    { file: original_path, status: :ok }
  else
    { file: original_path, status: :different, differences: differences }
  end
end

def compare_directories(original_dir, generated_dir, options = {})
  unless Dir.exist?(original_dir)
    puts "Error: Original directory not found: #{original_dir}"
    exit 1
  end

  unless Dir.exist?(generated_dir)
    puts "Error: Generated directory not found: #{generated_dir}"
    puts "Hint: Run 'bundle exec rbs-inline --output' to generate RBS files from inline annotations"
    exit 1
  end

  results = []

  Dir.glob("#{original_dir}/**/*.rbs").each do |original_file|
    relative_path = original_file.sub("#{original_dir}/", "")
    generated_file = File.join(generated_dir, relative_path)

    results << compare_files(original_file, generated_file, options)
  end

  results
end

def output_results(results, options = {})
  all_passed = results.all? { |r| r[:status] == :ok }

  if options[:json]
    require "json"
    puts JSON.pretty_generate({
      passed: all_passed,
      total: results.length,
      passed_count: results.count { |r| r[:status] == :ok },
      failed_count: results.count { |r| r[:status] != :ok },
      results: results
    })
    return all_passed
  end

  return all_passed if options[:quiet] && all_passed

  puts "=" * 60
  puts "RBS Comparison Results"
  puts "=" * 60
  puts

  results.each do |result|
    case result[:status]
    when :ok
      puts "✅ #{result[:file]}" unless options[:quiet]
    when :error
      puts "❌ #{result[:file]} - #{result[:message]}"
    when :missing
      puts "❌ #{result[:file]} - #{result[:message]}"
    when :different
      puts "⚠️  #{result[:file]} - #{result[:differences].length} difference(s)"
      result[:differences].each do |diff|
        case diff[:type]
        when :missing_in_original
          puts "   + In generated only: #{diff[:member_type]} #{diff[:item] || diff[:method]}"
        when :missing_in_generated
          puts "   - In original only: #{diff[:member_type]} #{diff[:item] || diff[:method]}"
        when :method_mismatch
          puts "   ~ Method signature differs: #{diff[:method]}"
          puts "     Original:  #{format_method(diff[:original])}"
          puts "     Generated: #{format_method(diff[:generated])}"
        end
      end
    end
  end

  puts
  puts "=" * 60
  if all_passed
    puts "All RBS files match! ✅"
  else
    puts "Some RBS files have differences ❌"
  end
  puts "=" * 60

  all_passed
end

def main
  options = {}
  args = []

  ARGV.each do |arg|
    case arg
    when "-h", "--help"
      print_usage
      exit 0
    when "--dir"
      options[:dir] = true
    when "--json"
      options[:json] = true
    when "--quiet"
      options[:quiet] = true
    when "--strict-param-names"
      options[:strict_param_names] = true
    else
      args << arg
    end
  end

  if args.length < 2
    print_usage
    exit 1
  end

  results = if options[:dir]
    compare_directories(args[0], args[1], options)
  else
    [compare_files(args[0], args[1], options)]
  end

  all_passed = output_results(results, options)
  exit(all_passed ? 0 : 1)
end

def format_method(method_info)
  overloads = method_info[:overloads].map do |o|
    params = format_params(o[:params])
    block = o[:block] ? " { ... }" : ""
    "(#{params})#{block} -> #{o[:return_type]}"
  end
  overloads.join(" | ")
end

def format_params(params)
  parts = []
  parts += params[:required_positionals].map { |p| p[:type] }
  parts += params[:optional_positionals].map { |p| "?#{p[:type]}" }
  parts << "*#{params[:rest_positionals][:type]}" if params[:rest_positionals]
  parts += params[:required_keywords].map { |k, v| "#{k}: #{v}" }
  parts += params[:optional_keywords].map { |k, v| "?#{k}: #{v}" }
  parts << "**#{params[:rest_keywords][:type]}" if params[:rest_keywords]
  parts.join(", ")
end

main
