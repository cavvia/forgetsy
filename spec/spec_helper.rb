require File.expand_path("../../lib/forgetsy.rb", __FILE__)

RSpec.configure do |c|
  c.before(:each) do
    redis = Forgetsy.redis
    redis.flushdb
  end
end
