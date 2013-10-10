require 'redis'

module Hipster

  class Connection

    def self.fetch
      Redis.new(db: 3)
    end
  end
end
