require_relative './set'

module Forgetsy
  # An abstraction used to extract trending scores
  # from two Forgetsy::Set instances decaying at
  # differing rates.
  class Delta
    attr_accessor :name
    # the time multiplier to use for the
    # normalising set.
    NORM_T_MULT = 2

    def initialize(name, opts = {})
      @name = name

      if opts.key?(:t)
        # we set the last decayed date of the secondary set to older than
        # the primary, in order to support retrospective observations.
        secondary_date = Time.now - ((Time.now - opts[:date]) * Forgetsy::Delta::NORM_T_MULT)

        Forgetsy::Set.create(primary_set_key,
                             t: opts[:t],
                             date: opts[:date])

        Forgetsy::Set.create(secondary_set_key,
                             t: opts[:t] * Forgetsy::Delta::NORM_T_MULT,
                             date: secondary_date)
      end
    end

    # Factory method. Use this instead of direct
    # instantiation to create a new delta.
    #
    # This will generate two Set instances decaying at a rate ratio
    # of 1:2.
    #
    # @param float opts[t] : mean lifetime of an observation (secs).
    # @param bool opts[replay] : whether to replay events retrospectively.
    # @param datetime opts[date] : a manual date to start replaying from.
    def self.create(name, opts = {})
      unless opts.key?(:t)
        raise ArgumentError,
             "Please specify a mean lifetime using the 't' option".freeze
      end

      if opts[:replay]
        opts[:date] = Time.now - opts[:t]
      else
        opts[:date] ||= Time.now
      end

      Forgetsy::Delta.new(name, opts)
    end

    # Fetch an existing delta instance.
    def self.fetch(name)
      delta = Forgetsy::Delta.new(name)
      unless delta.exists?
        raise NameError,
             "No delta with that name exists".freeze
      end
      delta
    end

    # Fetch all scores, or optionally ask for
    # the top n results, or an individual bin.
    #
    #   delta.fetch
    #   delta.fetch(n: 20)
    #   delta.fetch(bin: 'foo')
    #
    # @return Hash
    def fetch(opts = {})

      # do not delegate the limit to sets
      # as we want to apply the limit after norm.
      limit = opts.delete(:n)
      bin = opts.key?(:bin) ? opts[:bin] : nil

      if bin.nil?
        counts = primary_set.fetch(opts)
        norm = secondary_set.fetch(opts)
        result = counts.map do |k, v|
          norm_v = norm.fetch(k, nil)
          v = norm_v.nil? ? 0 : v / Float(norm_v)
          [k, v]
        end
      else
        # fetch a single bin.
        counts = primary_set.fetch(opts)
        norm = secondary_set.fetch(opts)

        if norm[bin].nil?
          result = [[bin, nil]]
        else
          norm_v = counts[bin] / Float(norm[bin])
          result = [[bin, norm_v]]
        end
      end

      result = result[0..limit - 1] unless limit.nil?
      Hash[result.map{ |r| [r[0], r[1]] }]
    end

    # Increment a bin. Additionally supply a date option
    # to replay historical data.
    def incr(bin, opts = {})
      sets.each { |set| set.incr(bin, opts) }
    end

    def incr_by(bin, by, opts = {})
      sets.each { |set| set.incr_by(bin, by, opts) }
    end

    def primary_set
      Forgetsy::Set.fetch(primary_set_key)
    end

    def secondary_set
      Forgetsy::Set.fetch(secondary_set_key)
    end

    def sets
      [primary_set, secondary_set]
    end

    def exists?
      Forgetsy.redis.hexists(
        Forgetsy::Set::METADATA_KEY,
        "#{primary_set_key}:#{Forgetsy::Set::LIFETIME_KEY}"
      )
    end

    private

    def primary_set_key
      @name
    end

    def secondary_set_key
      "#{@name}_2t"
    end
  end
end
