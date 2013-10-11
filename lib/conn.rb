require 'redis'

module Forgetsy

  # Redis connection.
  class Connection

    def self.fetch
      Redis.new(db: 3)
    end
  end
end
