require "active_support"
require File.expand_path("../../lib/forgetsy.rb", __FILE__)

RSpec.configure do |c|
  c.before(:each) do
    redis = Forgetsy.redis
    redis.redis.flushdb # Avoid blind passthrough
  end
end
