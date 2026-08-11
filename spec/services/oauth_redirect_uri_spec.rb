require "rails_helper"

RSpec.describe OauthRedirectUri do
  describe "cleartext?" do
    it "is true for http, which puts the grant on the wire" do
      expect(OauthRedirectUri.cleartext?("http://example.com/oauth")).to be_truthy
      expect(OauthRedirectUri.cleartext?("HTTP://example.com/oauth")).to be_truthy
    end

    it "is false for https" do
      expect(OauthRedirectUri.cleartext?("https://example.com/oauth")).to be_falsey
    end

    it "is false for the custom schemes native apps redirect to" do
      ["bikeindex://oauth-callback", "org.bikeindex.app:/oauth", "urn:ietf:wg:oauth:2.0:oob"].each do |redirect_uri|
        expect(OauthRedirectUri.cleartext?(redirect_uri)).to be_falsey
      end
    end

    it "is false for loopback, which never leaves the device" do
      ["http://localhost:3000/oauth", "http://LOCALHOST:3000/oauth", "http://127.0.0.1:3000/oauth", "http://[::1]:3000/oauth"].each do |redirect_uri|
        expect(OauthRedirectUri.cleartext?(redirect_uri)).to be_falsey
      end
    end

    it "is false for blank and unparseable uris" do
      [nil, "", "http://exa mple.com"].each do |redirect_uri|
        expect(OauthRedirectUri.cleartext?(redirect_uri)).to be_falsey
      end
    end
  end
end
