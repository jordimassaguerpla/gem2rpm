$:.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'test/unit'
require 'rubygems'
require 'rubygems/version'
require 'gem2rpm'

class TestVersionConversion < Test::Unit::TestCase

  def test_simple_conversion
    r = Gem::Requirement.new("> 1.0")
    assert_equal(["> 1.0"] ,r.to_rpm)
  end

  def test_match_any_version_conversion
    r = Gem::Requirement.new("> 0.0.0")
    assert_equal([""] ,r.to_rpm)
  end

  def test_match_ranged_version_conversion
    r = Gem::Requirement.new(["> 1.2", "< 2.0"])
    assert_equal(["> 1.2", "< 2.0"] ,r.to_rpm)
  end

  def test_first_level_pessimistic_version_constraint
    r = Gem::Requirement.new(["~> 1.2"])
    assert_equal(["=> 1.2", "< 2"] ,r.to_rpm)
  end

  def test_second_level_pessimistic_version_constraint
    r = Gem::Requirement.new(["~> 1.2.3"])
    assert_equal(["=> 1.2.3", "< 1.3"] ,r.to_rpm)
  end

  def test_pessimistic_version_constraint_with_trailing_text
    # Trailing text was only allowed starting around rubygems 1.3.2.
    gem_version = Gem::Version.create(Gem::RubyGemsVersion)
    if gem_version >= Gem::Version.create("1.3.2")
      r = Gem::Requirement.new(["~> 1.2.3.beta.8"])
      assert_equal(["=> 1.2.3.beta.8", "< 1.3"] ,r.to_rpm)
    end
  end

  def test_second_level_pessimistic_version_constraint_with_two_digit_version
    r = Gem::Requirement.new(["~> 1.12.3"])
    assert_equal(["=> 1.12.3", "< 1.13"] ,r.to_rpm)
  end

  def test_omitting_development_requirements_from_spec
    # Only run this test if rubygems 1.2.0 or later.
    if Gem::Version.create(Gem::RubyGemsVersion) >= Gem::Version.create("1.2.0")
      out = StringIO.new

      gem_path = File.join(File.dirname(__FILE__), "artifacts", "testing_gem", "testing_gem-1.0.0.gem") 
      Gem2Rpm::convert(gem_path, Gem2Rpm::TEMPLATE, out, false)

      assert_no_match(/\sRequires: rubygem\(test_development\)/, out.string)
    end
  end

  def test_omitting_url_from_rpm_spec
    out = StringIO.new

    gem_path = File.join(File.dirname(__FILE__), "artifacts", "testing_gem", "testing_gem-1.0.0.gem") 

    Gem2Rpm::convert(gem_path, Gem2Rpm::TEMPLATE, out, false)

    assert_match(/\s#FIXME cannot obtain URL /, out.string)
  end

  def test_rubygems_version_requirement
    out = StringIO.new

    gem_path = File.join(File.dirname(__FILE__), "artifacts", "testing_gem", "testing_gem-1.0.0.gem") 

    Gem2Rpm::convert(gem_path, Gem2Rpm::TEMPLATE, out, false)

    #assert_match(/\sRequires: rubygems >= 1.3.6/, out.string)
    assert_match(/\sRequires: ruby-gems >= 1.8.11/, out.string)
  end

  def test_rubys_version_requirement
    out = StringIO.new

    gem_path = File.join(File.dirname(__FILE__), "artifacts", "testing_gem", "testing_gem-1.0.0.gem") 

    Gem2Rpm::convert(gem_path, Gem2Rpm::TEMPLATE, out, false)

    assert_match(/\sRequires: ruby >= 1.8.6/, out.string)
    assert_match(/\sBuildRequires: ruby >= 1.8.6/, out.string)
  end

  def test_rpm_version_transform_opensuse_equals_operator
    version = Gem::Version.create("1.0.0")
    actual = Gem::Requirement::rpm_version_transform_opensuse("name","=",version)
    expected = ["name = 1.0.0"]
    assert_equal(expected,actual)
  end

  def test_rpm_version_transform_opensuse_tilde_operator
    version = Gem::Version.create("1.0.0")
    actual = Gem::Requirement::rpm_version_transform_opensuse("name","~>",version)
    expected = ["name-1_0 >= 1.0.0"] 
    assert_equal(expected,actual)
  end

  def test_rpm_version_transform_opensuse_equals_operator_version_null
    version = Gem::Version.create(0)
    actual = Gem::Requirement::rpm_version_transform_opensuse("name","=",version)
    expected = ["name"] 
    assert_equal(expected,actual)
  end

  def test_word_wrap
    actual = ""
    expected = "1"
    39.times { expected = expected + " 1" }
    expected = expected + "\n1"
    41.times { actual = actual + " 1" }
    actual = actual.word_wrap
    assert_equal(expected, actual)
  end

end
