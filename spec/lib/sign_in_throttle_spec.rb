require "rails_helper"

RSpec.describe SignInThrottle do
  let(:app) { ->(env) { [200, {"content-type" => "text/plain"}, ["OK"]] } }
  let(:cache) { Redis.new(url: Rails.application.config.redis_cache_url) }
  let(:middleware) { described_class.new(app, cache:) }

  after { cache.del("sign_in_throttle:127.0.0.1") }

  def post_request(path)
    env = Rack::MockRequest.env_for(path, :method => "POST", "REMOTE_ADDR" => "127.0.0.1")
    middleware.call(env)
  end

  def get_request(path)
    env = Rack::MockRequest.env_for(path, :method => "GET", "REMOTE_ADDR" => "127.0.0.1")
    middleware.call(env)
  end

  describe "POST /session" do
    it "allows requests under the limit" do
      status, _headers, _body = post_request("/session")
      expect(status).to eq 200
    end

    it "returns 429 after exceeding the limit" do
      SignInThrottle::MAX_REQUESTS.times { post_request("/session") }
      status, headers, body = post_request("/session")
      expect(status).to eq 429
      expect(headers["retry-after"]).to eq "60"
      expect(body).to eq ["Too Many Requests"]
    end
  end

  describe "POST /oauth/token" do
    it "returns 429 after exceeding the limit" do
      SignInThrottle::MAX_REQUESTS.times { post_request("/oauth/token") }
      status, _headers, _body = post_request("/oauth/token")
      expect(status).to eq 429
    end
  end

  describe "non-throttled requests" do
    it "does not throttle GET /session/new" do
      (SignInThrottle::MAX_REQUESTS + 5).times { get_request("/session/new") }
      status, _headers, _body = get_request("/session/new")
      expect(status).to eq 200
    end

    it "does not throttle POST to other paths" do
      (SignInThrottle::MAX_REQUESTS + 5).times { post_request("/bikes") }
      status, _headers, _body = post_request("/bikes")
      expect(status).to eq 200
    end
  end
end
