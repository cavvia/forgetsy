require 'spec_helper'

describe "Forgetsy::Set" do

  before(:each) do
    @redis = Forgetsy.redis
    @set = Forgetsy::Set.create('foo', t: WEEK)
  end

  describe 'creation' do
    it 'creates a redis set with the appropriate name and stores metadata' do
      @redis.zcount('foo', '-inf', '+inf').should == 2
    end

    it 'stores the last decayed date in a special key upon creation' do
      Timecop.freeze(Time.now) do
        manual_date = Time.now - (3 * WEEK)
        a = Forgetsy::Set.create('bar', t: WEEK, date: manual_date)
        a.last_decayed_date.should == manual_date.to_f
      end
    end

    it 'stores the mean lifetime in a special key upon creation' do
      @set.lifetime.should == WEEK.to_f
    end

    it 'fails with an argument error when no :t option is supplied' do
      error = false
      begin
        @set = Forgetsy::Set.create('foo')
      rescue ArgumentError
        error = true
      end
      error.should == true
    end
  end

  describe 'increments' do
    it 'increments counters correctly' do
      @set.incr('foo_bin')
      @redis.zscore('foo', 'foo_bin').should == 1.0
    end

    it 'increments in batches' do
      @set.incr_by('foo_bin', 5)
      @redis.zscore('foo', 'foo_bin').should == 5.0
    end

    it 'ignores an increment with a date older than the last decay date' do
      manual_date = Time.now - (2 * WEEK)
      lifetime = 2 * WEEK
      @set = Forgetsy::Set.create('foo', t: lifetime, date: manual_date)
      @set.incr('foo_bin', date: Time.now - 3 * WEEK)
      @set.fetch(bin: 'foo_bin').values.first.should == nil
    end

    it 'increments counters when the set is created at the same time as the increment' do
      manual_date = Time.now - 2 * WEEK
      lifetime = 2 * WEEK
      @set = Forgetsy::Set.create('foo', t: lifetime, date: manual_date)
      @set.incr('foo_bin', date: manual_date)
      @set.fetch(bin: 'foo_bin').values.first.should_not == nil
    end
  end

  describe 'fetch' do
    it 'allows fetch by bin name' do
      @set.incr_by('foo_bin', 2)
      @set.fetch(bin: 'foo_bin', decay: false).should == { 'foo_bin' => 2.0 }
    end

    it 'can fetch top n bins' do
      @set.incr_by('foo_bin', 2)
      @set.incr_by('bar_bin', 1)
      @set.fetch(n: 2, decay: false).should == { 'foo_bin' => 2.0, 'bar_bin' => 1.0 }
    end

    it 'can fetch a whole set' do
      @set.incr_by('foo_bin', 2)
      @set.incr_by('bar_bin', 1)
      @set.fetch(decay: false).should == { 'foo_bin' => 2.0, 'bar_bin' => 1.0 }
    end
  end

  describe 'decay' do
    it 'decays counts exponentially' do
      now = Time.now
      Timecop.freeze(now) do
        manual_date = Time.now - (2 * DAY)
        time_delta = now - manual_date
        lifetime = WEEK
        foo, bar = 2, 10

        rate = 1 / Float(lifetime)
        @set = Forgetsy::Set.create('foo', t: lifetime, date: manual_date)
        @set.incr_by('foo_bin', foo)
        @set.incr_by('bar_bin', bar)

        decayed_foo = foo * Math.exp(- rate * time_delta)
        decayed_bar = bar * Math.exp(- rate * time_delta)

        @set.decay(date: now)
        @set.fetch(bin: 'foo_bin').values.first.should == decayed_foo
        @set.fetch(bin: 'bar_bin').values.first.should == decayed_bar
      end
    end
  end

  describe 'scrub' do
    it 'scrubs keys below a defined threshold during a fetch' do
      manual_date = Time.now - (12 * MONTH)
      lifetime = WEEK
      @set = Forgetsy::Set.create('foo', t: lifetime, date: manual_date)
      @set.incr('foo_bin')
      @set.fetch.values.length.should == 0
    end
  end
end
