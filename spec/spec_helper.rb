require File.expand_path("../../lib/set.rb", __FILE__)
require File.expand_path("../../lib/delta.rb", __FILE__)
require File.expand_path("../../lib/conn.rb", __FILE__)
require 'active_support/core_ext'


RSpec.configure do |c|
  c.before(:each) do
    redis = Hipster::Connection.fetch
    redis.flushdb
  end
end
