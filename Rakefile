require "rake"
require "rake/clean"
require "rake/gempackagetask"
require "rake/rdoctask"
require "rake/testtask"
require "spec/rake/spectask"
require "fileutils"

def __DIR__
  File.dirname(__FILE__)
end

include FileUtils

GEM_NAME = "declarations"
GEM_VERSION = "1.0"

def sudo
  ENV['DECLS_SUDO'] ||= "sudo"
  sudo = windows? ? "" : ENV['DECLS_SUDO']
end

def windows?
  (PLATFORM =~ /win32|cygwin/) rescue nil
end

def install_home
  ENV['GEM_HOME'] ? "-i #{ENV['GEM_HOME']}" : ""
end

##############################################################################
# Packaging & Installation
##############################################################################
CLEAN.include ["**/.*.sw?", "pkg", "lib/*.bundle", "*.gem", "doc/rdoc", ".config", "coverage", "cache"]

desc "Run the specs."
task :default => :specs

task :declarations => [:clean, :rdoc, :package]

spec = Gem::Specification.new do |s|
  s.name         = GEM_NAME
  s.version      = GEM_VERSION
  s.platform     = Gem::Platform::RUBY
  s.author       = "Oleg Andreev"
  s.email        = "oleganza@gmail.com"
  s.homepage     = "http://oleganza.com/"
  s.summary      = "Inheritable declarations for Ruby classes and modules."
  s.bindir       = "bin"
  s.description  = s.summary
  s.executables  = %w(  )
  s.require_path = "lib"
  s.files        = %w( MIT-LICENSE README Rakefile ) + Dir["{spec,lib}/**/*"]

  # rdoc
  s.has_rdoc         = true
  s.extra_rdoc_files = %w( README MIT-LICENSE )
  #s.rdoc_options     += RDOC_OPTS + ["--exclude", "^(app|uploads)"]
end

Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
end

desc "Run :package and install the resulting .gem"
task :install => :package do
  sh %{#{sudo} gem install #{install_home} --local pkg/#{GEM_NAME}-#{GEM_VERSION}.gem --no-rdoc --no-ri}
end

desc "Run :package and install the resulting .gem with jruby"
task :jinstall => :package do
  sh %{#{sudo} jruby -S gem install #{install_home} pkg/#{GEM_NAME}-#{GEM_VERSION}.gem --no-rdoc --no-ri}
end

desc "Run :clean and uninstall the .gem"
task :uninstall => :clean do
  sh %{#{sudo} gem uninstall #{GEM_NAME}}
end
