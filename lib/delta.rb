require 'set'

module Forgetsy

  # An abstraction used to extract trending scores
  # from two Forgetsy::Set instances decaying at
  # differing rates.
  class Delta
    attr_accessor :name, :conn

    # the time multiplier to use for the
    # normalising set.
    @@norm_t_mult = 2

    def initialize(name, opts = {})
      @name = name
      setup_conn

      if opts.key?(:t)
        Forgetsy::Set.create(primary_set_key,
                             t: opts[:t],
                             date: opts[:date])

        Forgetsy::Set.create(secondary_set_key,
                             t: opts[:t] * @@norm_t_mult,
                             date: opts[:date])
      end
    end

    # Factory method. Use this instead of direct
    # instantiation to create a new delta.
    #
    # This will generate two Set instances decaying at a rate ratio
    # of 1:2.
    #
    # @param float opts[t] : mean lifetime of an observation (secs).
    # @param datetime opts[date] : a manual date to start decaying from.
    def self.create(name, opts = {})
      unless opts.key?(:t)
        fail ArgumentError,
             "Please specify a mean lifetime using the 't' option"
      end

      opts[:date] ||= Time.now
      Forgetsy::Delta.new(name, opts)
    end

    # Fetch an existing delta instance.
    def self.fetch(name)
      delta = Forgetsy::Delta.new(name)
      unless delta.exists?
        fail NameError,
             'No delta with that name exists'
      end
    end

    # Fetch all scores, or optionally ask for
    # the top n results, or an individual bin.
    #
    #   delta.fetch()
    #   delta.fetch(n: 20)
    #   delta.fetch(bin: 'foo')
    #
    # @return Hash
    def fetch(opts = {})

      # do not delegate the limit to sets
      # as we want to apply the limit after norm.
      limit = opts[:n]
      opts.delete(:n)
      bin = opts.key?(:bin) ? opts[:bin] : nil

      if bin.nil?
        counts = primary_set.fetch
        norm = secondary_set.fetch
        result = counts.map do |k, v|
          norm_v = norm.fetch(k, nil)
          v = norm_v.nil? ? 0 : v / Float(norm_v)
          [k, v]
        end
      else
        # fetch a single bin.
        counts = primary_set.fetch(opts)
        norm = secondary_set.fetch(opts)

        if ! norm.key?(bin)
          result = [bin, 0.0]
        else
          norm_v = counts[bin] / Float(norm[bin])
          result = [bin, norm_v]
        end
      end

      result = result[0..limit - 1] unless limit.nil?
      Hash[*result.flatten]
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
      @conn.exists(@name)
    end

    private

    def setup_conn
      @conn ||= Forgetsy::Connection.fetch
    end

    def primary_set_key
      @name
    end

    def secondary_set_key
      "#{@name}_2t"
    end
  end
end
