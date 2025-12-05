# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "fileutils"
require "open3"

class CompareRBSScriptTest < Minitest::Test
  SCRIPT_PATH = File.expand_path("../../scripts/compare_rbs.rb", __dir__)
  FIXTURES_DIR = File.expand_path("fixtures", __dir__)

  def fixture_path(name)
    File.join(FIXTURES_DIR, name)
  end

  def run_script(*args)
    stdout, stderr, status = Open3.capture3("ruby", SCRIPT_PATH, *args)
    { stdout: stdout, stderr: stderr, status: status }
  end

  # === Basic Matching ===

  def test_identical_files_match
    result = run_script(
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_matching.rbs")
    )

    assert result[:status].success?, "Identical files should match (exit 0)"
    assert_match(/All RBS files match/, result[:stdout])
  end

  def test_files_with_param_names_match_by_default
    result = run_script(
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_with_param_names.rbs")
    )

    assert result[:status].success?,
      "Files differing only in param names should match with default settings"
  end

  def test_files_with_param_names_differ_in_strict_mode
    result = run_script(
      "--strict-param-names",
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_with_param_names.rbs")
    )

    refute result[:status].success?,
      "Files differing in param names should NOT match in strict mode"
    assert_match(/difference/, result[:stdout])
  end

  # === Missing Methods ===

  def test_detects_missing_method_in_generated
    result = run_script(
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_missing_method.rbs")
    )

    refute result[:status].success?, "Should detect missing method (exit 1)"
    assert_match(/In original only.*method.*valid\?/i, result[:stdout])
  end

  def test_detects_extra_method_in_generated
    result = run_script(
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_extra_method.rbs")
    )

    refute result[:status].success?, "Should detect extra method (exit 1)"
    assert_match(/In generated only.*method.*extra_method/i, result[:stdout])
  end

  # === Return Type Differences ===

  def test_detects_return_type_mismatch
    result = run_script(
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_wrong_return_type.rbs")
    )

    refute result[:status].success?, "Should detect return type mismatch (exit 1)"
    assert_match(/Method signature differs.*full_name/i, result[:stdout])
  end

  # === Generics ===

  def test_generic_class_with_param_names_matches
    result = run_script(
      fixture_path("original_container.rbs"),
      fixture_path("generated_container_matching.rbs")
    )

    assert result[:status].success?,
      "Generic class files differing only in param names should match"
  end

  # === Overloaded Methods ===

  def test_overloaded_methods_with_param_names_match
    result = run_script(
      fixture_path("original_with_overloads.rbs"),
      fixture_path("generated_with_overloads_matching.rbs")
    )

    assert result[:status].success?,
      "Overloaded methods differing only in param names should match"
  end

  # === Error Handling ===

  def test_returns_error_for_missing_original
    result = run_script(
      fixture_path("nonexistent.rbs"),
      fixture_path("generated_user_matching.rbs")
    )

    refute result[:status].success?
    assert_match(/not found/i, result[:stdout])
  end

  def test_returns_error_for_missing_generated
    result = run_script(
      fixture_path("original_user.rbs"),
      fixture_path("nonexistent.rbs")
    )

    refute result[:status].success?
    assert_match(/not found/i, result[:stdout])
  end

  # === JSON Output ===

  def test_json_output_format
    result = run_script(
      "--json",
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_matching.rbs")
    )

    assert result[:status].success?

    parsed = JSON.parse(result[:stdout])
    assert_equal true, parsed["passed"]
    assert_equal 1, parsed["total"]
    assert_equal 1, parsed["passed_count"]
    assert_equal 0, parsed["failed_count"]
  end

  def test_json_output_with_differences
    result = run_script(
      "--json",
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_missing_method.rbs")
    )

    refute result[:status].success?

    parsed = JSON.parse(result[:stdout])
    assert_equal false, parsed["passed"]
    assert_equal 1, parsed["failed_count"]
    assert parsed["results"].first["differences"].any?
  end

  # === Quiet Mode ===

  def test_quiet_mode_suppresses_output_on_success
    result = run_script(
      "--quiet",
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_matching.rbs")
    )

    assert result[:status].success?
    # In quiet mode, successful comparisons produce minimal output
    refute_match(/original_user\.rbs/, result[:stdout])
  end

  def test_quiet_mode_shows_output_on_failure
    result = run_script(
      "--quiet",
      fixture_path("original_user.rbs"),
      fixture_path("generated_user_missing_method.rbs")
    )

    refute result[:status].success?
    # In quiet mode, failures still produce output
    assert_match(/difference/i, result[:stdout])
  end

  # === Help ===

  def test_help_flag
    result = run_script("--help")

    assert result[:status].success?
    assert_match(/Usage:/, result[:stdout])
    assert_match(/--strict-param-names/, result[:stdout])
  end

  def test_missing_arguments_shows_usage
    result = run_script

    refute result[:status].success?
    assert_match(/Usage:/, result[:stdout])
  end
end

class CompareRBSDirectoryTest < Minitest::Test
  SCRIPT_PATH = File.expand_path("../../scripts/compare_rbs.rb", __dir__)

  def setup
    @temp_dir = File.join(Dir.tmpdir, "rbs_compare_test_#{$$}_#{rand(10000)}")
    @original_dir = File.join(@temp_dir, "original")
    @generated_dir = File.join(@temp_dir, "generated")

    FileUtils.mkdir_p(@original_dir)
    FileUtils.mkdir_p(@generated_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def run_script(*args)
    stdout, stderr, status = Open3.capture3("ruby", SCRIPT_PATH, *args)
    { stdout: stdout, stderr: stderr, status: status }
  end

  def test_compare_directories_finds_all_files
    File.write(File.join(@original_dir, "a.rbs"), "class A\n  def foo: () -> void\nend\n")
    File.write(File.join(@generated_dir, "a.rbs"), "class A\n  def foo: () -> void\nend\n")

    File.write(File.join(@original_dir, "b.rbs"), "class B\n  def bar: () -> void\nend\n")
    File.write(File.join(@generated_dir, "b.rbs"), "class B\n  def bar: () -> void\nend\n")

    result = run_script("--dir", @original_dir, @generated_dir)

    assert result[:status].success?, "All matching files should pass"
    assert_match(/All RBS files match/, result[:stdout])
  end

  def test_compare_directories_reports_missing_generated
    File.write(File.join(@original_dir, "exists.rbs"), "class Exists\nend\n")
    # Don't create generated file

    result = run_script("--dir", @original_dir, @generated_dir)

    refute result[:status].success?
    assert_match(/not found/i, result[:stdout])
  end

  def test_compare_directories_handles_nested_structure
    FileUtils.mkdir_p(File.join(@original_dir, "nested"))
    FileUtils.mkdir_p(File.join(@generated_dir, "nested"))

    File.write(File.join(@original_dir, "nested", "deep.rbs"), "class Deep\n  def x: () -> void\nend\n")
    File.write(File.join(@generated_dir, "nested", "deep.rbs"), "class Deep\n  def x: () -> void\nend\n")

    result = run_script("--dir", @original_dir, @generated_dir)

    assert result[:status].success?
  end

  def test_compare_directories_with_json_output
    File.write(File.join(@original_dir, "a.rbs"), "class A\n  def foo: () -> void\nend\n")
    File.write(File.join(@generated_dir, "a.rbs"), "class A\n  def foo: () -> void\nend\n")

    File.write(File.join(@original_dir, "b.rbs"), "class B\n  def bar: () -> void\nend\n")
    # Missing b.rbs in generated

    result = run_script("--dir", "--json", @original_dir, @generated_dir)

    refute result[:status].success?

    parsed = JSON.parse(result[:stdout])
    assert_equal 2, parsed["total"]
    assert_equal 1, parsed["passed_count"]
    assert_equal 1, parsed["failed_count"]
  end
end
