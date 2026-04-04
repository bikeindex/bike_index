require "rails_helper"

RSpec.describe SignInThrottle do
  include_context :sign_in_throttle

  let(:app) { ->(env) { [200, {"content-type" => "text/plain"}, ["OK"]] } }
  let(:cache) { Redis.new(url: Rails.application.config.redis_cache_url) }
  let(:middleware) { described_class.new(app, cache:) }

  after do
    cache.keys("sign_in_throttle:*").each { |key| cache.del(key) }
  end

  def post_request(path)
    env = Rack::MockRequest.env_for(path, :method => "POST", "REMOTE_ADDR" => "127.0.0.1")
    middleware.call(env)
  end

  def get_request(path)
    env = Rack::MockRequest.env_for(path, :method => "GET", "REMOTE_ADDR" => "127.0.0.1")
    middleware.call(env)
  end

  describe "sign-in paths (10/min)" do
    it "allows requests under the limit" do
      status, _headers, _body = post_request("/session")
      expect(status).to eq 200
    end

    it "returns 429 after exceeding the limit" do
      SignInThrottle::SIGN_IN_MAX.times { post_request("/session") }
      status, headers, body = post_request("/session")
      expect(status).to eq 429
      expect(headers["retry-after"]).to eq "60"
      expect(body).to eq ["Too Many Requests"]
    end

    it "throttles POST /oauth/token" do
      SignInThrottle::SIGN_IN_MAX.times { post_request("/oauth/token") }
      status, _headers, _body = post_request("/oauth/token")
      expect(status).to eq 429
    end
  end

  describe "sensitive paths (5/min)" do
    %w[
      /session/create_magic_link
      /session/sign_in_with_magic_link
      /users/send_password_reset_email
      /users/update_password_with_reset_token
      /users/resend_confirmation_email
    ].each do |path|
      context "POST #{path}" do
        it "returns 429 after exceeding the limit" do
          SignInThrottle::SENSITIVE_MAX.times { post_request(path) }
          status, _headers, _body = post_request(path)
          expect(status).to eq 429
        end
      end
    end

    context "POST /user_emails/:id/resend_confirmation" do
      it "returns 429 after exceeding the limit" do
        SignInThrottle::SENSITIVE_MAX.times { post_request("/user_emails/123/resend_confirmation") }
        status, _headers, _body = post_request("/user_emails/123/resend_confirmation")
        expect(status).to eq 429
      end
    end
  end

  describe "non-throttled requests" do
    it "does not throttle GET requests" do
      15.times { get_request("/session/new") }
      status, _headers, _body = get_request("/session/new")
      expect(status).to eq 200
    end

    it "does not throttle POST to other paths" do
      15.times { post_request("/bikes") }
      status, _headers, _body = post_request("/bikes")
      expect(status).to eq 200
    end
  end

  context "when disabled" do
    around do |example|
      SignInThrottle.enabled = false
      example.run
    ensure
      SignInThrottle.enabled = true
    end

    it "passes through without throttling" do
      15.times { post_request("/session") }
      status, _headers, _body = post_request("/session")
      expect(status).to eq 200
    end
  end
end
