require 'spec_helper'

describe WebhookRunner do
  describe 'make_request' do
    it "doesn't error if webhook doesn't return" do
      runner = WebhookRunner.new
      response = runner.make_request('https://testing.bikeindex.org/about/something')
      expect(response).to be_present
    end
  end

  describe 'after_bike_update' do
    it 'calls make request' do
      runner = WebhookRunner.new
      id = 9999
      expect(runner).to receive(:hook_urls).with('after_bike_update').and_return(['http://tester.com/bikes/#{bike_id}'])
      expect(runner).to receive(:make_request).with("http://tester.com/bikes/#{id}")
      runner.after_bike_update(id)
    end

    it "doesn't fail if there aren't any urls" do
      runner = WebhookRunner.new
      id = 9999
      Redis.new.expire(runner.redis_id('after_bike_update'), 0)
      expect(runner.after_bike_update(id)).to be_truthy
    end
  end

  describe 'after_user_update' do
    it 'calls make request' do
      runner = WebhookRunner.new
      id = 9999
      expect(runner).to receive(:hook_urls).with('after_user_update').and_return(['http://tester.com/users/#{user_id}'])
      expect(runner).to receive(:make_request).with("http://tester.com/users/#{id}")
      runner.after_user_update(id)
    end

    it "doesn't fail if there aren't any urls" do
      runner = WebhookRunner.new
      id = 9999
      Redis.new.expire(runner.redis_id('after_user_update'), 0)
      expect(runner.after_user_update(id)).to be_truthy
    end
  end

  describe 'hook_urls' do
    it 'calls the redis array' do
      runner = WebhookRunner.new
      redis = Redis.new
      rid = runner.redis_id('after_bike_update')
      redis.expire(rid, 0)
      redis.lpush(rid, 'http://tester.com')
      expect(redis.lrange(rid, 0, 0)).to eq(['http://tester.com'])
      expect(runner.hook_urls('after_bike_update')).to eq(redis.lrange(rid, 0, 0))
    end
  end
end
