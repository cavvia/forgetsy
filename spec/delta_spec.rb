require 'spec_helper'

describe "Forgetsy::Delta" do

  before(:each) do
    @redis = Forgetsy.redis
  end

  describe 'creation' do
    it 'creates two set instances with appropriate keys' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.should be_kind_of(Forgetsy::Delta)
      set = delta.primary_set
      set.should be_kind_of(Forgetsy::Set)
      @redis.exists(set.name).should == true
      set = delta.secondary_set
      set.should be_kind_of(Forgetsy::Set)
      @redis.exists(set.name).should == true
    end
  end

  describe 'retrospective creation' do
    it 'sets last decay date of secondary set to older than that of the primary' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.should be_kind_of(Forgetsy::Delta)
      primary_set = delta.primary_set
      secondary_set = delta.secondary_set
      secondary_set.last_decayed_date.should < primary_set.last_decayed_date
    end
  end

  describe 'fetch' do
    it 'fetches normalised counts when fetching a single bin' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr('foo_bin')
      delta.incr('foo_bin')
      delta.incr('bar_bin')
      delta.fetch(bin: 'foo_bin').values.first.round(1).should == 1.0
      delta.fetch(bin: 'bar_bin').values.first.round(1).should == 1.0
    end

    it 'passes options on to sets' do
      opts = { decay: false }
      mock_set = double()
      expect(mock_set).to receive(:fetch).with(opts) { [] }
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr('foo_bin')
      delta.stub(:primary_set) { mock_set }
      delta.fetch(opts)
    end

    it 'returns nil when trying to fetch a non-existent bin' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
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
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr('foo_bin')
      delta.incr('foo_bin')
      delta.incr('bar_bin')
      all_scores = delta.fetch()
      all_scores.keys[0].should == 'foo_bin'
      all_scores.keys[1].should == 'bar_bin'
      all_scores.values[0].round(1).should == 1.0
      all_scores.values[1].round(1).should == 1.0
    end

    it 'limits results when using :n option' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr_by('foo_bin', 3)
      delta.incr_by('bar_bin', 2)
      delta.incr('quux_bin')
      all_scores = delta.fetch(n: 2)
      all_scores.length.should == 2
      all_scores = delta.fetch()
      all_scores.length.should == 3
    end
  end


end
