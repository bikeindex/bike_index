require 'spec_helper'

describe WebhookRunner do

  describe :make_request do 
    it "doesn't error if webhook doesn't return" do
      runner = WebhookRunner.new 
      response = runner.make_request("https://testing.bikeindex.org/about/something")
      response.should be_present
    end
  end

  describe :after_bike_update do 
    it "calls make request" do
      runner = WebhookRunner.new
      id = 9999
      runner.should receive(:hook_urls).with('after_bike_update').and_return(['http://tester.com/bikes/#{bike_id}'])
      runner.should receive(:make_request).with("http://tester.com/bikes/#{id}")
      runner.after_bike_update(id)
    end

    it "doesn't fail if there aren't any urls" do 
      runner = WebhookRunner.new
      id = 9999
      Redis.new.expire(runner.redis_id('after_bike_update'), 0)
      runner.after_bike_update(id).should be_true
    end
  end

  describe :after_user_update do
    it "calls make request" do
      runner = WebhookRunner.new
      id = 9999
      runner.should receive(:hook_urls).with('after_user_update').and_return(['http://tester.com/users/#{user_id}'])
      runner.should receive(:make_request).with("http://tester.com/users/#{id}")
      runner.after_user_update(id)
    end

    it "doesn't fail if there aren't any urls" do 
      runner = WebhookRunner.new
      id = 9999
      Redis.new.expire(runner.redis_id('after_user_update'), 0)
      runner.after_user_update(id).should be_true
    end
  end

  describe :hook_urls do 
    it "calls the redis array" do 
      runner = WebhookRunner.new
      redis = Redis.new
      rid = runner.redis_id('after_bike_update')
      redis.expire(rid, 0)
      redis.lpush(rid, 'http://tester.com')
      redis.lrange(rid, 0, 0).should eq(['http://tester.com'])
      runner.hook_urls('after_bike_update').should eq(redis.lrange(rid, 0, 0))
    end
  end

end
