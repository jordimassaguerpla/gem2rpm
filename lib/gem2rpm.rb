require 'erb'
require 'socket'
require 'rubygems/format'
require 'gem2rpm/distro'

# Adapt to the differences between rubygems < 1.0.0 and after
# Once we can be reasonably certain that everybody has version >= 1.0.0
# all this logic should be killed
GEM_VERSION = Gem::Version.create(Gem::RubyGemsVersion)
HAS_REMOTE_INSTALLER = GEM_VERSION < Gem::Version.create("1.0.0")

if HAS_REMOTE_INSTALLER
  require 'rubygems/remote_installer'
end

# Extend String with a word_wrap method, which we use in the ERB template
# below.  Taken with modification from the word_wrap method in ActionPack.
# Text::Format does the smae thing better.
class String
  def word_wrap(line_width = 80)
    gsub(/\n/, "\n\n").gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip
  end
end

module Gem
  class Requirement
    def self.rpm_version_transform(op, version)
      if op == '~>'
        # note:
        #
        # while this works in most cases it can lead to buggy systems
        # Requires: rubygem-foo >= 1.0.0 rubygem-foo < 1.1
        #
        # rubygem-foo-0.9: Provides: rubygem-foo = 0.9
        # rubygem-foo-1.0: Provides: rubygem-foo = 1.0
        # rubygem-foo-1.1: Provides: rubygem-foo = 1.1
        #
        # rubygem-foo-1.1 satisfies the >= 1.0.0 part and rubygem-foo-0.9
        # satisfies the < 1.1 part but neither of them is a version that would
        # satisfy the gem dependency.
        #
        # A cleaner solution might be converting it to a "=" requirement
        # but that adds a lot of work on the maintainer.
        #
        # Or adding the requires on the versioned package name
        # Requires: rubygem-foo-1.0 >= 1.0.0
        #
        # For a programmatic way to transform this, we would need to pass
        # name into the rpm_version_transform method or move the whole transformation
        # logic out of the Gem::Requirement class.
        #
        next_version = Gem::Version.create(version).bump.to_s
        return ["=> #{version}", "< #{next_version}"]
      end
      return ["#{op} #{version}"] unless Gem::Version.new(0) == version
      return [""]
    end

    def self.rpm_version_transform_opensuse(name, op, version)
      if op == '~>'
        version_parts = version.bump.to_s.split('.')
        version_parts[-1] = (Integer(version_parts[-1])-1).to_s
        op = '>='
        name = "#{name}-#{version_parts.join('_')}"
      end
      return ["#{name} #{op} #{version}"] unless Gem::Version.new(0) == version
      return ["#{name}"]
    end

    def to_rpm
      return requirements.map { |op, version| self.class.rpm_version_transform(op, version) }.flatten
    end

  end
end

module Gem2Rpm
  Gem2Rpm::VERSION = "0.6.0"

  if HAS_REMOTE_INSTALLER
    def self.find_download_url(name, version)
      installer = Gem::RemoteInstaller.new
      dummy, download_path = installer.find_gem_to_install(name, "=#{version}")
      download_path += "/gems/" if download_path.to_s != ""
      raise Gem::Exception, "not a download_path for #{name} = #{version}", caller unless download_path
      return download_path
    end
  else
    def self.find_download_url(name, version)
      dep = Gem::Dependency.new(name, "=#{version}")
      fetcher = Gem::SpecFetcher.fetcher
      dummy, download_path = fetcher.find_matching(dep, false, false).first
      download_path += "gems/" if download_path.to_s != ""
      raise Gem::Exception, "not a download_path for #{name} = #{version}", caller unless download_path
      return download_path
    end
  end

  def Gem2Rpm.convert(fname, template=TEMPLATE, out=$stdout,
                      nongem=true, local=false, doc_subpackage = true)
    format = Gem::Format.from_file_by_path(fname)
    spec = format.spec
    spec.description ||= spec.summary
    download_path = ""
    unless local
      begin
        download_path = find_download_url(spec.name, spec.version)
        spec.homepage = download_path
      rescue Gem::Exception => e
        $stderr.puts "Warning: Could not retrieve full URL for #{spec.name}\nWarning: Edit the specfile and enter the full download URL as 'Source0' manually"
        $stderr.puts "#{e.inspect}"
      end
    end
    template = ERB.new(template, 0, '<>')
    out.puts template.result(binding)
  end

  # Returns the email address of the packager (i.e., the person running
  # gem2spec).  Taken from RPM macros if present, constructed from system
  # username and hostname otherwise.
  def Gem2Rpm.packager()
    packager = `rpmdev-packager`.chomp

    if packager.empty?
      packager = `rpm --eval '%{packager}'`.chomp
    end

    if packager.empty? or packager == '%{packager}'
      packager = "#{Etc::getpwnam(Etc::getlogin).gecos} <#{Etc::getlogin}@#{Socket::gethostname}>"
    end

    packager
  end

  TEMPLATE = File.read File.join(File.dirname(__FILE__), '..', 'templates', "#{Distro.nature.to_s}.spec.erb")
end

# Local Variables:
# ruby-indent-level: 2
# End:
