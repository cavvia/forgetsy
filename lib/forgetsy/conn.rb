require 'redis'
require 'yaml'

module Forgetsy

  # Redis connection.
  class Connection

    def self.fetch
      @@conn ||= Redis.new(self.config)
    end

    def self.config
      path = File.expand_path("../../../config/redis.yml", __FILE__)
      @@config ||= YAML.load_file(path).fetch('redis')
    end
  end
end
