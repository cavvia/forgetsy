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

  gem.add_runtime_dependency 'redis', '>= 2.0.12'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'fakeredis'
  gem.add_development_dependency 'timecop'
  gem.add_development_dependency 'redis-namespace', '>= 1.1.0'
end
