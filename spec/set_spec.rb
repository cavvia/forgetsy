require 'spec_helper'

describe "Forgetsy::Set" do

  before(:each) do
    @redis = Forgetsy.redis
    @set = Forgetsy::Set.create('foo', t: 1.week)
  end

  describe 'creation' do
    it 'creates a redis set with the appropriate name and stores metadata' do
      expect(@redis.zcount('foo', '-inf', '+inf')).to eq(2)
    end

    it 'stores the last decayed date in a special key upon creation' do
      manual_date = 3.weeks.ago
      a = Forgetsy::Set.create('bar', t: 1.week, date: manual_date)
      expect(a.last_decayed_date).to eq(manual_date.to_f.round(7))
    end

    it 'stores the mean lifetime in a special key upon creation' do
      expect(@set.lifetime).to eq(1.week.to_f)
    end

    it 'fails with an argument error when no :t option is supplied' do
      error = false
      begin
        @set = Forgetsy::Set.create('foo')
      rescue ArgumentError
        error = true
      end
      expect(error).to eq(true)
    end
  end

  describe 'increments' do
    it 'increments counters correctly' do
      @set.incr('foo_bin')
      expect(@redis.zscore('foo', 'foo_bin')).to eq(1.0)
    end

    it 'increments in batches' do
      @set.incr_by('foo_bin', 5)
      expect(@redis.zscore('foo', 'foo_bin')).to eq(5.0)
    end

    it 'ignores an increment with a date older than the last decay date' do
      manual_date = 2.weeks.ago
      lifetime = 2.weeks
      @set = Forgetsy::Set.create('foo', t: lifetime, date: manual_date)
      @set.incr('foo_bin', date: 3.weeks.ago)
      expect(@set.fetch(bin: 'foo_bin').values.first).to eq(nil)
    end
  end

  describe 'fetch' do
    it 'allows fetch by bin name' do
      @set.incr_by('foo_bin', 2)
      expect(@set.fetch(bin: 'foo_bin', decay: false)).to eq({ 'foo_bin' => 2.0 })
    end

    it 'can fetch top n bins' do
      @set.incr_by('foo_bin', 2)
      @set.incr_by('bar_bin', 1)
      expect(@set.fetch(n: 2, decay: false)).to eq({ 'foo_bin' => 2.0, 'bar_bin' => 1.0 })
    end

    it 'can fetch a whole set' do
      @set.incr_by('foo_bin', 2)
      @set.incr_by('bar_bin', 1)
      expect(@set.fetch(decay: false)).to eq({ 'foo_bin' => 2.0, 'bar_bin' => 1.0 })
    end
  end

  describe 'decay' do
    it 'decays counts exponentially' do
      manual_date = 2.days.ago
      now = Time.now
      time_delta = now - manual_date
      lifetime = 1.week
      foo, bar = 2, 10

      rate = 1 / Float(lifetime)
      @set = Forgetsy::Set.create('foo', t: lifetime, date: manual_date)
      @set.incr_by('foo_bin', foo)
      @set.incr_by('bar_bin', bar)

      decayed_foo = foo * Math.exp(- rate * time_delta)
      decayed_bar = bar * Math.exp(- rate * time_delta)

      @set.decay(date: now)
      expect(@set.fetch(bin: 'foo_bin').values.first.round(3)).to eq(decayed_foo.round(3))
      expect(@set.fetch(bin: 'bar_bin').values.first.round(3)).to eq(decayed_bar.round(3))
    end
  end

  describe 'scrub' do
    it 'scrubs keys below a defined threshold during a fetch' do
      manual_date = 12.months.ago
      lifetime = 1.week
      @set = Forgetsy::Set.create('foo', t: lifetime, date: manual_date)
      @set.incr('foo_bin')
      expect(@set.fetch.values.length).to eq(0)
    end
  end
end
