require "rails_helper"

RSpec.describe CspReport do
  let(:blocked_uri) { "https://evil.example.com/x.js" }
  let(:effective_directive) { "script-src" }
  let(:document_uri) { "https://bikeindex.org/bikes/1" }
  let(:report) { {"blocked-uri" => blocked_uri, "document-uri" => document_uri, "effective-directive" => effective_directive} }
  let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/148.0.0.0 Safari/537.36" }

  describe "parse" do
    it "pulls the report out of the envelope" do
      expect(described_class.parse({"csp-report" => report}.to_json)).to eq report
    end

    ["not json", "null", "123", {"csp-report" => 5}.to_json].each do |raw_body|
      it "returns nil for #{raw_body.inspect}" do
        expect(described_class.parse(raw_body)).to be_nil
      end
    end
  end

  describe "normalize" do
    it "leaves a uri without a query alone" do
      expect(described_class.normalize(report)).to eq report
    end

    context "blocked-uri with a query string" do
      let(:blocked_uri) { "https://evil.example.com/x.js?label=WADeCPKg7gYQtvfc0wM&guid=ON" }

      it "drops the query, so the fault doesn't fingerprint per-request" do
        expect(described_class.normalize(report)["blocked-uri"]).to eq "https://evil.example.com/x.js"
      end
    end

    context "blocked-uri that isn't a url" do
      let(:blocked_uri) { "data" }

      it "leaves it alone" do
        expect(described_class.normalize(report)).to eq report
      end
    end
  end

  describe "noise?" do
    it "is false for a violation we can act on" do
      expect(described_class.noise?(report, user_agent)).to be_falsey
    end

    context "browser-extension noise" do
      let(:blocked_uri) { "chrome-extension://0dca8e62/fonts/Inter-Variable.ttf" }
      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "in-app browser user agent" do
      let(:user_agent) { "Mozilla/5.0 (Linux; Android 12) Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/488.0.0.78.79;]" }
      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "google country-domain frame (origin only, no path)" do
      let(:blocked_uri) { "https://www.google.co.id" }
      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "private-ip frame injection" do
      let(:blocked_uri) { "https://10.255.99.112" }
      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "read-aloud data: media" do
      let(:blocked_uri) { "data" }
      let(:effective_directive) { "media-src" }
      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "translated document" do
      let(:document_uri) { "https://bikeindex-org.translate.goog" }
      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "blocked by a policy that isn't ours" do
      # An extension tightening our header still reports to our report-uri
      let(:blocked_uri) { "https://www.googletagmanager.com/gtm.js?id=GTM-K88RMWC" }
      let(:effective_directive) { "script-src-elem" }

      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "an old browser sending the sources alongside the directive name" do
      let(:report) do
        {"blocked-uri" => "https://www.google-analytics.com/analytics.js", "document-uri" => document_uri,
         "violated-directive" => "script-src https://www.googletagmanager.com"}
      end

      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "a host our policy does not allow" do
      let(:blocked_uri) { "https://images.simplycodes.com/tracker.gif" }
      let(:effective_directive) { "img-src" }

      it "is false" do
        expect(described_class.noise?(report, user_agent)).to be_falsey
      end
    end

    context "a font from a third party" do
      # Coupon and citation extensions inject page-level <link>s
      let(:blocked_uri) { "https://images.simplycodes.com/fonts/CircularXXWeb-Medium.woff2" }
      let(:effective_directive) { "font-src" }

      it "is true" do
        expect(described_class.noise?(report, user_agent)).to be_truthy
      end
    end

    context "a font from our own origin" do
      let(:blocked_uri) { "https://bikeindex.org/assets/inter.woff2" }
      let(:effective_directive) { "font-src" }

      it "is false" do
        expect(described_class.noise?(report, user_agent)).to be_falsey
      end
    end

    context "same-origin blocked-uri our policy would allow" do
      # 'self' permits it, so this is a redirect to a target the browser won't name
      let(:blocked_uri) { "https://bikeindex.org/payments" }
      let(:document_uri) { "https://bikeindex.org/donate" }
      let(:effective_directive) { "connect-src" }

      it "is false" do
        expect(described_class.noise?(report, user_agent)).to be_falsey
      end
    end
  end

  describe "permits?" do
    def permits?(directive, uri)
      described_class.send(:permits?, directive, URI.parse(uri))
    end

    # blocked-uri / effective-directive pairs taken from the top CSP faults
    context "hosts our policy allowlists" do
      [["script-src-elem", "https://www.googletagmanager.com/gtm.js?id=GTM-K88RMWC"],
        ["script-src", "https://connect.facebook.net/en_US/all.js"],
        ["img-src", "https://www.googleadservices.com/pagead/conversion/980892598/"],
        ["img-src", "https://stats.g.doubleclick.net/g/collect"],
        ["img-src", "https://region1.google-analytics.com/g/collect"],
        ["font-src", "https://fonts.gstatic.com/s/inter/v13/x.woff2"],
        ["connect-src", "https://region1.google-analytics.com/g/collect"], # a *. source
        ["connect-src", "https://analytics.google.com/g/collect"],
        ["connect-src", "https://region1.analytics.google.com/g/collect"],
        ["frame-src", "https://js.stripe.com"]].each do |directive, uri|
        it "permits #{directive} #{uri}" do
          expect(permits?(directive, uri)).to be_truthy
        end
      end
    end

    context "hosts our policy does not allowlist" do
      [["font-src", "https://images.simplycodes.com/fonts/CircularXXWeb-Medium.woff2"],
        ["frame-src", "https://youtu.be"],
        # a *. source matches on the label boundary, not a bare suffix
        ["connect-src", "https://analytics.google.com.evil.com/g/collect"],
        ["img-src", "https://evil.example.com/tracker.gif"]].each do |directive, uri|
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
