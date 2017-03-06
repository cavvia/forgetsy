require 'rake'
require 'rspec/core/rake_task'

desc "Run all tests"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/*_spec.rb"
end

task :default => "spec"
