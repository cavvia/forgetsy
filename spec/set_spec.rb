require 'spec_helper'

describe "Hipster::Set" do

  before(:each) do
    @redis = Hipster::Connection.fetch
    @set = Hipster::Set.new('foo', t: 1.week)
  end

  describe 'creation' do
    it "creates a redis set with the appropriate name and stores metadata" do
      @redis.zcount('foo', '-inf', '+inf').should == 2
    end

    it "stores the last decayed date in a special key upon creation" do
      manual_date = 3.weeks.ago
      a = Hipster::Set.new('bar', t: 1.week, date: manual_date)
      a.last_decayed_date.should == manual_date.to_f.round(7)
    end

    it "stores the mean lifetime in a special key upon creation" do
      @set.lifetime.should == 1.week.to_f
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
  end

  describe 'fetch' do
    it 'allows fetch by bin name' do
      @set.incr_by('foo_bin', 2)
      @set.fetch(bin: 'foo_bin', decay: false).should == { 'foo_bin' => 2.0 }
    end

    it 'can fetch top n bins' do
      @set.incr_by('foo_bin', 2)
      @set.incr_by('bar_bin', 1)
      @set.fetch(n: 2, decay: false).should == { 'foo_bin' => 2.0, 'bar_bin' => 1.0}
    end

    it 'can fetch a whole set' do
      @set.incr_by('foo_bin', 2)
      @set.incr_by('bar_bin', 1)
      @set.fetch(decay: false).should == { 'foo_bin' => 2.0, 'bar_bin' => 1.0}
    end
  end

  describe 'decay' do
    it 'decays counts exponentially' do
      @set.incr_by('foo_bin', 2)
      @set.incr_by('bar_bin', 10)
      @set.decay
      @set.fetch(bin: 'foo_bin').values.first.should < 2
      @set.fetch(bin: 'bar_bin').values.first.should < 10
    end
  end

end
