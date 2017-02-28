require 'spec_helper'

describe "Forgetsy::Delta" do

  before(:each) do
    @redis = Forgetsy.redis
  end

  describe 'creation' do
    it "creates two set instances with appropriate Redis metadata" do
      now = Time.now
      delta = Timecop.freeze(now) do
        Forgetsy::Delta.create('foo', t: WEEK)
      end
      delta.should be_kind_of(Forgetsy::Delta)
      set = delta.primary_set
      set.should be_kind_of(Forgetsy::Set)
      set = delta.secondary_set
      set.should be_kind_of(Forgetsy::Set)
      expect(@redis.hgetall("_forgetsy")).to eq({
        "foo:_last_decay"=>now.to_f.to_s,
        "foo:_t"=>"604800.0",
        "foo_2t:_last_decay"=>now.to_f.to_s,
        "foo_2t:_t"=>"1209600.0",
      })
    end
  end

  describe 'retrospective creation' do
    it 'sets last decay date of secondary set to older than that of the primary' do
      delta = Forgetsy::Delta.create('foo', t: WEEK)
      delta.should be_kind_of(Forgetsy::Delta)
      primary_set = delta.primary_set
      secondary_set = delta.secondary_set
      secondary_set.last_decayed_date.should < primary_set.last_decayed_date
    end
  end

  describe 'fetch' do
    it 'fetches normalised counts when fetching a single bin' do
      now = Time.now
      delta = nil
      Timecop.freeze(now) do
        delta = Forgetsy::Delta.create('foo', t: WEEK)
      end
      Timecop.freeze(now + 1) do
        delta.incr('foo_bin')
        delta.incr('foo_bin')
        delta.incr('bar_bin')
        delta.fetch(bin: 'foo_bin').values.first.should == 0.999999173280765
        delta.fetch(bin: 'bar_bin').values.first.should == 0.999999173280765
      end
    end

    it 'passes options on to sets' do
      opts = { decay: false }
      mock_set = double()
      mock_set.should_receive(:fetch).with(opts) { [] }
      delta = Forgetsy::Delta.create('foo', t: WEEK)
      delta.incr('foo_bin')
      delta.stub(:primary_set) { mock_set }
      delta.fetch(opts)
    end

    it 'returns nil when trying to fetch a non-existent bin' do
      delta = Forgetsy::Delta.create('foo', t: WEEK)
      delta.fetch(bin: 'foo_bin').should == {'foo_bin' => nil }
    end

    it 'raises a value error if a delta with that name does not exist' do
      error = false
      begin
        Forgetsy::Delta.fetch('foo')
      rescue NameError
        error = true
      end
      error.should == true
    end

    it 'fetches normalised counts when fetching all scores' do
      now = Time.now
      delta = nil
      Timecop.freeze(now) do
        delta = Forgetsy::Delta.create('foo', t: WEEK)
      end
      Timecop.freeze(now + 1) do
        delta.incr('foo_bin')
        delta.incr('foo_bin')
        delta.incr('bar_bin')
        all_scores = delta.fetch()
        all_scores.keys[0].should == 'foo_bin'
        all_scores.keys[1].should == 'bar_bin'
        all_scores.values[0].should == 0.999999173280765
        all_scores.values[1].should == 0.999999173280765
      end
    end

    it 'limits results when using :n option' do
      delta = Forgetsy::Delta.create('foo', t: WEEK)
      delta.incr_by('foo_bin', 3)
      delta.incr_by('bar_bin', 2)
      delta.incr('quux_bin')
      all_scores = delta.fetch(n: 2)
      all_scores.length.should == 2
      all_scores = delta.fetch()
      all_scores.length.should == 3
    end

    it "works with retroactive events" do
      now = Time.now
      Timecop.freeze(now) do
        follows_delta = Forgetsy::Delta.create('user_follows', t: WEEK, replay: true)
      end
      Timecop.freeze(now + 1) do
        follows_delta = Forgetsy::Delta.fetch('user_follows')
        follows_delta.incr('UserFoo', date: Time.now - 2 * WEEK)
        follows_delta.incr('UserBar', date: Time.now - 10 * DAY)
        follows_delta.incr('UserBar', date: Time.now - 1 * WEEK)
        follows_delta.incr('UserFoo', date: Time.now - 1 * DAY)
        follows_delta.incr('UserFoo')
        follows_delta.fetch['UserFoo'].should == 0.66666611552051
        follows_delta.fetch['UserBar'].should == 0.4999995866403826
      end
    end
  end

end
