require "active_support"
require File.expand_path("../../lib/forgetsy.rb", __FILE__)
require "fakeredis/rspec"

RSpec.configure do |c|
  c.before(:all) do
    Forgetsy.redis = Redis.new
  end

  c.after(:each) do
    Forgetsy.redis.flushdb
  end
end
