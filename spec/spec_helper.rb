require File.expand_path("../../lib/forgetsy.rb", __FILE__)
require "fakeredis/rspec"
require "timecop"

SECOND = 1
MINUTE = 60 * SECOND
HOUR = 60 * MINUTE
DAY = 24 * HOUR
WEEK = 7 * DAY
MONTH = 30 * DAY

RSpec.configure do |c|
  c.before(:all) do
    Forgetsy.redis = Redis.new
  end

  c.after(:each) do
    Forgetsy.redis.flushdb
  end
end
