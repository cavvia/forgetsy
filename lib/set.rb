module Forgetsy

  # A data structure that decays counts exponentially
  # over time. Decay is applied at read time.
  class Set
    attr_accessor :name, :conn

    @@last_decayed_key = '_last_decay'
    @@lifetime_key = '_t'

    # Stores mean lifetime and last decay date
    # in special keys on creation.
    #
    # @param float opts[:t] : mean lifetime of an observation in secs.
    # @param opts[:date] : a manual date to start decaying from.
    def initialize(name, opts = {})
      @name = name

      unless opts.key?(:t)
        raise ArgumentError, "Please specify a mean lifetime using the 't' option"
      end

      setup_conn
      date = opts[:date] || Time.now
      update_decay_date(date)
      conn.zadd(name, opts[:t].to_f, @@lifetime_key)
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

    def incr(bin)
      @conn.zincrby(@name, 1, bin)
    end

    def incr_by(bin, by)
      @conn.zincrby(@name, by, bin)
    end

    def last_decayed_date
      @conn.zscore(@name, @@last_decayed_key)
    end

    def lifetime
      @conn.zscore(@name, @@lifetime_key)
    end

    private

    # Buffer the limit as special keys may be in
    # top n results.
    def fetch_raw(opts = {})
      limit = opts[:limit] || -1
      buffered_limit = limit

      if limit > 0
        buffered_limit = limit + special_keys.length
      end

      set = @conn.zrevrange(@name, 0, buffered_limit, withscores: true)
      filter_special_keys(set)[0..limit]
    end

    def update_decay_date(date)
      @conn.zadd(@name, date.to_f, @@last_decayed_key)
    end

    def setup_conn
      @conn ||= Forgetsy::Connection.fetch
    end

    def special_keys
      [@@lifetime_key, @@last_decayed_key]
    end

    def filter_special_keys(set)
      set.select { |k| not special_keys.include?(k[0]) }
    end
  end

end
