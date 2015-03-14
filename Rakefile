require "bundler/gem_tasks"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = ['--tty --color --format documentation']
end
task :default => :spec

require 'rake/javaextensiontask'

# Dependency jars for the Kerrigan ext build
jars = [
  "#{ENV['MY_RUBY_HOME']}/lib/jruby.jar",
  "lib/jar/httpcore-4.3.3.jar",
  "lib/jar/httpclient-4.3.6.jar"
]
Rake::JavaExtensionTask.new do |ext|
  ext.name = "manticore-ext"
  ext.lib_dir = "lib/jar"
  ext.classpath = jars.map {|x| File.expand_path x}.join ':'
end