# frozen_string_literal: true
require "forgetsy/set"
require "forgetsy/delta"
require "logger"
require "redis"

module Forgetsy
  # Accepts:
  #   1. An instance of `Redis`, `Redis::Client`, `Redis::DistRedis`,
  #      `Redis::Namespace`, etc. (i.e. an existing Redis client instance)
  #   2. A hash of options to pass through to `Redis.new`. If a `:namespace`
  #      key is also provided, that will not be passed through to `Redis.new`
  #      but rather used to initialize a `Redis::Namespace`.
  def self.redis=(options)
    if options.is_a?(Hash)
      namespace = options.delete(:namespace)
      client = Redis.new(options)
      if namespace
        begin
          require "redis/namespace"
          @redis = Redis::Namespace.new(namespace, :redis => client)
        rescue LoadError
          self.logger.error("Your Redis configuration uses the namespace " \
            "'#{namespace}' but the redis-namespace gem is not included in " \
            "the Gemfile. Add the gem to your Gemfile to continue using a " \
            "namespace. Otherwise, remove the namespace parameter.")
          raise
        end
      else
        @redis = client
      end
    else
      # Assume `options` is an already-initialized Redis client instance
      @redis = options
    end
  end

  def self.redis
    defined?(@redis) ? @redis : (@redis = Redis.current)
  end

  def self.logger
    defined?(@logger) ? @logger : initialize_logger
  end

  def self.initialize_logger(log_target = STDOUT)
    oldlogger = defined?(@logger) ? @logger : nil
    @logger = Logger.new(log_target)
    @logger.level = Logger::INFO
    oldlogger.close if oldlogger
    @logger
  end
end
