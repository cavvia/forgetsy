require 'spec_helper'

describe "Forgetsy::Delta" do

  before(:each) do
    @redis = Forgetsy.redis
  end

  describe 'creation' do
    it 'creates two set instances with appropriate keys' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      expect(delta).to be_kind_of(Forgetsy::Delta)
      set = delta.primary_set
      expect(set).to be_kind_of(Forgetsy::Set)
      expect(@redis.exists(set.name)).to eq(true)
      set = delta.secondary_set
      expect(set).to be_kind_of(Forgetsy::Set)
      expect(@redis.exists(set.name)).to eq(true)
    end
  end

  describe 'retrospective creation' do
    it 'sets last decay date of secondary set to older than that of the primary' do
      delta = Forgetsy::Delta.create('foo', t: 1.week, replay: true)
      expect(delta).to be_kind_of(Forgetsy::Delta)
      primary_set = delta.primary_set
      secondary_set = delta.secondary_set
      expect(secondary_set.last_decayed_date).to be < primary_set.last_decayed_date
    end
  end

  describe 'fetch' do
    it 'fetches normalised counts when fetching a single bin' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr('foo_bin')
      delta.incr('foo_bin')
      delta.incr('bar_bin')
      expect(delta.fetch(bin: 'foo_bin').values.first.round(1)).to eq(1.0)
      expect(delta.fetch(bin: 'bar_bin').values.first.round(1)).to eq(1.0)
    end

    it 'passes options on to sets' do
      opts = { decay: false }
      mock_set = double()
      expect(mock_set).to receive(:fetch).with(opts) { [] }
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr('foo_bin')
      allow(delta).to receive(:primary_set) { mock_set }
      delta.fetch(opts)
    end

    it 'returns nil when trying to fetch a non-existent bin' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      expect(delta.fetch(bin: 'foo_bin')).to eq({'foo_bin' => nil })
    end

    it 'raises a value error if a delta with that name does not exist' do
      error = false
      begin
        Forgetsy::Delta.fetch('foo')
      rescue NameError
        error = true
      end
      expect(error).to eq(true)
    end

    it 'fetches normalised counts when fetching all scores' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr('foo_bin')
      delta.incr('foo_bin')
      delta.incr('bar_bin')
      all_scores = delta.fetch()
      expect(all_scores.keys[0]).to eq('foo_bin')
      expect(all_scores.keys[1]).to eq('bar_bin')
      expect(all_scores.values[0].round(1)).to eq(1.0)
      expect(all_scores.values[1].round(1)).to eq(1.0)
    end

    it 'limits results when using :n option' do
      delta = Forgetsy::Delta.create('foo', t: 1.week)
      delta.incr_by('foo_bin', 3)
      delta.incr_by('bar_bin', 2)
      delta.incr('quux_bin')
      all_scores = delta.fetch(n: 2)
      expect(all_scores.length).to eq(2)
      all_scores = delta.fetch()
      expect(all_scores.length).to eq(3)
    end

    it "works with retroactive events" do
      follows_delta = Forgetsy::Delta.create('user_follows', t: 1.week, replay: true)
      follows_delta = Forgetsy::Delta.fetch('user_follows')
      follows_delta.incr('UserFoo', date: 2.weeks.ago)
      follows_delta.incr('UserBar', date: 10.days.ago)
      follows_delta.incr('UserBar', date: 1.week.ago)
      follows_delta.incr('UserFoo', date: 1.day.ago)
      follows_delta.incr('UserFoo')
      expect(follows_delta.fetch['UserFoo'].round(2)).to eq(0.67)
      expect(follows_delta.fetch['UserBar'].round(2)).to eq(0.50)
    end
  end

end
