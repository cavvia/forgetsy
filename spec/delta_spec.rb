require 'spec_helper'

describe "Forgetsy::Delta" do

  before(:each) do
    @redis = Forgetsy::Connection.fetch
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

  describe 'fetch' do

    it 'fetches normalised counts when fetching a single bin' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr('foo_bin')
      delta.incr('foo_bin')
      delta.incr('bar_bin')
      delta.fetch(bin: 'foo_bin').values.first.round(1).should == 1.0
      delta.fetch(bin: 'bar_bin').values.first.round(1).should == 1.0
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
  end


end
