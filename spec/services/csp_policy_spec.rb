require "rails_helper"

RSpec.describe CspPolicy do
  describe "permits?" do
    def permits?(directive, uri)
      described_class.permits?(directive, URI.parse(uri))
    end

    # blocked-uri / effective-directive pairs taken from the top CSP faults
    context "hosts our policy allowlists" do
      {
        "script-src-elem" => "https://www.googletagmanager.com/gtm.js?id=GTM-K88RMWC",
        "script-src" => "https://connect.facebook.net/en_US/all.js",
        "img-src" => "https://www.googleadservices.com/pagead/conversion/980892598/",
        "font-src" => "https://fonts.gstatic.com/s/inter/v13/x.woff2",
        "connect-src" => "https://region1.google-analytics.com/g/collect", # a *. source
        "frame-src" => "https://js.stripe.com"
      }.each do |directive, uri|
        it "permits #{directive} #{uri}" do
          expect(permits?(directive, uri)).to be_truthy
        end
      end
    end

    context "hosts our policy does not allowlist" do
      {
        "font-src" => "https://images.simplycodes.com/fonts/CircularXXWeb-Medium.woff2",
        "connect-src" => "https://region1.analytics.google.com", # analytics.google.com is exact-match only
        "frame-src" => "https://youtu.be",
        "img-src" => "https://evil.example.com/tracker.gif"
      }.each do |directive, uri|
        it "does not permit #{directive} #{uri}" do
          expect(permits?(directive, uri)).to be_falsey
        end
      end
    end

    context "a directive we don't declare" do
      it "falls back to script-src for script-src-attr" do
        expect(permits?("script-src-attr", "https://js.stripe.com/v3")).to be_truthy
      end

      it "falls back to default-src for media-src, which only allows self" do
        expect(permits?("media-src", "https://www.googletagmanager.com/gtm.js")).to be_falsey
      end
    end

    context "an old browser sending the sources alongside the name" do
      it "reads the directive name" do
        expect(permits?("script-src https://www.googletagmanager.com", "https://js.stripe.com/v3")).to be_truthy
      end
    end

    it "does not match a bare domain against a *. source" do
      expect(permits?("connect-src", "https://google-analytics.com/collect")).to be_falsey
    end

    it "requires the scheme to match" do
      expect(permits?("script-src", "http://js.stripe.com/v3")).to be_falsey
    end

    it "permits a scheme source" do
      expect(permits?("font-src", "data:font/woff2;base64,AAA")).to be_truthy
    end
  end
end
