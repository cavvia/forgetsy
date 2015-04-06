module Forgetsy
  # A data structure that decays counts exponentially
  # over time. Decay is applied at read time.
  class Set
    attr_accessor :name, :conn

    @@last_decayed_key = '_last_decay'
    @@lifetime_key = '_t'

    # scrub keys scoring lower than this.
    @@hi_pass_filter = 0.0001

    def initialize(name)
      @name = name
      setup_conn
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
             "Please specify a mean lifetime using the 't' option"
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
        result = [opts[:bin], @conn.zscore(@name, opts[:bin])]
      else
        result = fetch_raw(limit: limit)
      end

      Hash[*result.flatten]
    end

    # Apply exponential time decay and
    # update the last decay time.
    def decay(opts = {})
      t0 = last_decayed_date
      t1 = opts.fetch(:date, Time.now).to_f
      delta_t = t1 - t0
      set = fetch_raw
      rate = 1 / Float(lifetime)
      @conn.pipelined do
        set.each do |k, v|
          new_v = v * Math.exp(- delta_t * rate)
          @conn.zadd(@name, new_v, k)
        end
        update_decay_date(Time.now)
      end
    end

    def scrub
      @conn.zremrangebyscore(@name, '-inf', @@hi_pass_filter)
    end

    def incr(bin, opts = {})
      date = opts.fetch(:date, Time.now)
      @conn.zincrby(@name, 1, bin) if valid_incr_date(date)
    end

    def incr_by(bin, by, opts = {})
      date = opts.fetch(:date, Time.now)
      @conn.zincrby(@name, by, bin) if valid_incr_date(date)
    end

    def last_decayed_date
      @conn.zscore(@name, @@last_decayed_key)
    end

    def lifetime
      @conn.zscore(@name, @@lifetime_key)
    end

    def create_lifetime_key(t)
      @conn.zadd(@name, t.to_f, @@lifetime_key)
    end

    def update_decay_date(date)
      @conn.zadd(@name, date.to_f, @@last_decayed_key)
    end

    private

    # Fetch the set without decay applied.
    def fetch_raw(opts = {})
      limit = opts[:limit] || -1

      # Buffer the limit as special keys may be in
      # top n results.
      buffered_limit = limit
      buffered_limit += special_keys.length if limit > 0

      set = @conn.zrevrange(@name, 0, buffered_limit, withscores: true)
      filter_special_keys(set)[0..limit]
    end

    def setup_conn
      @conn ||= Forgetsy.redis
    end

    def special_keys
      [@@lifetime_key, @@last_decayed_key]
    end

    def filter_special_keys(set)
      set.select { |k| !special_keys.include?(k[0]) }
    end

    def valid_incr_date(date)
      date && date.to_f > last_decayed_date.to_f
    end
  end
end
