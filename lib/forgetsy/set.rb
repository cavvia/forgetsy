module Forgetsy
  # A data structure that decays counts exponentially
  # over time. Decay is applied at read time.
  class Set
    attr_accessor :name

    LAST_DECAYED_KEY = "_last_decay".freeze
    LIFETIME_KEY = "_t".freeze
    METADATA_KEY = "_forgetsy".freeze

    # scrub keys scoring lower than this.
    HIGH_PASS_FILTER = 0.0001

    def initialize(name)
      @name = name
    end

    # Factory method. Use this instead of direct
    # instantiation to create a new set.
    #
    # Stores mean lifetime and last decay date
    # in special keys on creation.
    #
    # @param float opts[t] : mean lifetime of an observation (secs).
    # @param datetime opts[date] : a manual date to start decaying from.
    def self.create(name, opts = {})
      unless opts.key?(:t)
        raise ArgumentError,
             "Please specify a mean lifetime using the 't' option".freeze
      end

      date = opts[:date] || Time.now

      set = Forgetsy::Set.new(name)
      set.update_decay_date(date)
      set.create_lifetime_key(opts[:t])
      set
    end

    # Fetch an existing set instance.
    def self.fetch(name)
      Forgetsy::Set.new(name)
    end

    # Fetch the entire set, or optionally ask for
    # the top :n results, or an individual :bin.
    #
    # @example Retrieve top n results
    #   set.fetch(n: 20)
    #
    # @example Retrieve an individual bin
    #   set.fetch(bin: 'foo')
    #
    # @return Hash
    def fetch(opts = {})
      limit = opts[:n] || -1
      decay if opts.fetch(:decay, true)
      scrub if opts.fetch(:scrub, true)

      if opts.key?(:bin)
        result = [[opts[:bin], redis.zscore(@name, opts[:bin])]]
      else
        result = fetch_raw(limit: limit)
      end

      Hash[result.map{ |r| [r[0], r[1]] }]
    end

    # Apply exponential time decay and
    # update the last decay time.
    def decay(opts = {})
      last_decayed_date, lifetime = last_decayed_date_and_lifetime
      t0 = last_decayed_date
      t1 = opts.fetch(:date, Time.now).to_f
      delta_t = t1 - t0
      set = fetch_raw
      rate = 1 / Float(lifetime)
      redis.pipelined do
        set.each do |k, v|
          new_v = v * Math.exp(- delta_t * rate)
          redis.zadd(@name, new_v, k)
        end
        update_decay_date(Time.now)
      end
    end

    def scrub
      redis.zremrangebyscore(@name, "-inf".freeze, HIGH_PASS_FILTER)
    end

    def incr(bin, opts = {})
      date = opts.fetch(:date, Time.now)
      redis.zincrby(@name, 1, bin) if valid_incr_date(date)
    end

    def incr_by(bin, by, opts = {})
      date = opts.fetch(:date, Time.now)
      redis.zincrby(@name, by, bin) if valid_incr_date(date)
    end

    def last_decayed_date
      redis.hget(METADATA_KEY, metadata_key(LAST_DECAYED_KEY)).to_f
    end

    def lifetime
      redis.hget(METADATA_KEY, metadata_key(LIFETIME_KEY)).to_f
    end

    def last_decayed_date_and_lifetime
      redis.hmget(
        METADATA_KEY, metadata_key(LAST_DECAYED_KEY),
        metadata_key(LIFETIME_KEY)
      ).map(&:to_f)
    end

    def create_lifetime_key(t)
      redis.hset(METADATA_KEY, metadata_key(LIFETIME_KEY), t.to_f)
    end

    def update_decay_date(date)
      redis.hset(METADATA_KEY, metadata_key(LAST_DECAYED_KEY), date.to_f)
    end

    def metadata_key(key)
      "#{@name}:#{key}"
    end

    private

    def redis(*args, &blk)
      Forgetsy.redis(*args, &blk)
    end

    # Fetch the set without decay applied.
    def fetch_raw(opts = {})
      limit = opts[:limit] || -1
      redis.zrevrange(@name, 0, limit, withscores: true)
    end

    def valid_incr_date(date)
      date && date.to_f >= last_decayed_date.to_f
    end
  end
end
