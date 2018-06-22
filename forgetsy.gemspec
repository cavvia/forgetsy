$:.unshift File.expand_path("../lib", __FILE__)
require 'forgetsy/version'

Gem::Specification.new do |gem|
  gem.name = "forgetsy"
  gem.homepage = "http://github.com/cavvia/forgetsy"
  gem.license = "MIT"
  gem.summary = %Q{A trending library built on redis.}
  gem.version = Forgetsy::VERSION

  gem.description = <<-EOS
    A scalable trending library that tracks temporal trends
    in data using forget-table style data structures.
  EOS

  gem.email = ["anil@cavvia.net"]
  gem.authors = ["Anil Bawa-Cavia"]

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- spec/*`.split("\n")

  gem.add_runtime_dependency 'redis', '> 2.0'
  gem.add_runtime_dependency 'redis-namespace', '>= 1.1.0'
  gem.add_runtime_dependency 'activesupport', '>= 3.2.0'
  gem.add_development_dependency 'rspec', '~> 2.14.0'
  gem.add_development_dependency 'rake', '~> 0.9'
end
