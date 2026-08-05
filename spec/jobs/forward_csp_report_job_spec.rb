require "rails_helper"

RSpec.describe ForwardCspReportJob, type: :job do
  let(:blocked_uri) { "https://evil.example.com/x.js" }
  let(:effective_directive) { "script-src" }
  let(:document_uri) { "https://bikeindex.org/bikes/1" }
  let(:report) { {"csp-report" => {"blocked-uri" => blocked_uri, "document-uri" => document_uri, "effective-directive" => effective_directive}} }
  let(:body) { report.to_json }
  let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/148.0.0.0 Safari/537.36" }
  let(:forwarded) { [] }
  let(:forwarded_blocked_uri) { forwarded.first&.dig("csp-report", "blocked-uri") }
  let(:forwarded_uris) { [] }

  before { stub_const("ForwardCspReportJob::HONEYBADGER_CSP_API_KEY", "abc123") }

  describe "#perform" do
    before do
      WebMock.stub_request(:post, /api\.honeybadger\.io/).to_return { |request|
        forwarded << JSON.parse(request.body)
        forwarded_uris << request.uri
        {status: 201}
      }
    end
    after { WebMock.reset! }

    def perform(request_body = body)
      described_class.new.perform(request_body, nil, user_agent)
    end

    it "does not forward outside production, even with an API key" do
      perform
      expect(forwarded).to be_empty
    end

    context "in production" do
      before { allow(Rails).to receive(:env).and_return("production".inquiry) }

      it "forwards a real violation to Honeybadger" do
        perform
        expect(forwarded_blocked_uri).to eq blocked_uri
      end

      it "sends the browser's user agent as context, not the forwarder's" do
        perform
        expect(CGI.unescape(forwarded_uris.first.to_s)).to include("context[user_agent]=#{user_agent}")
      end

      context "blocked-uri with a query string" do
        let(:blocked_uri) { "https://evil.example.com/x.js?label=WADeCPKg7gYQtvfc0wM&guid=ON" }

        it "forwards it without the query, so the fault doesn't fingerprint per-request" do
          perform
          expect(forwarded_blocked_uri).to eq "https://evil.example.com/x.js"
        end
      end

      context "without an API key" do
        before { stub_const("ForwardCspReportJob::HONEYBADGER_CSP_API_KEY", "") }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "browser-extension noise" do
        let(:blocked_uri) { "chrome-extension://0dca8e62/fonts/Inter-Variable.ttf" }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "in-app browser user agent" do
        let(:user_agent) { "Mozilla/5.0 (Linux; Android 12) Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/488.0.0.78.79;]" }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "google country-domain frame (origin only, no path)" do
        let(:blocked_uri) { "https://www.google.co.id" }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "private-ip frame injection" do
        let(:blocked_uri) { "https://10.255.99.112" }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "read-aloud data: media" do
        let(:blocked_uri) { "data" }
        let(:effective_directive) { "media-src" }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "blocked by a policy that isn't ours" do
        # An extension tightening our header still reports to our report-uri
        let(:blocked_uri) { "https://www.googletagmanager.com/gtm.js?id=GTM-K88RMWC" }
        let(:effective_directive) { "script-src-elem" }

        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "an old browser sending the sources alongside the directive name" do
        let(:report) { {"csp-report" => {"blocked-uri" => "https://www.google-analytics.com/analytics.js", "document-uri" => document_uri, "violated-directive" => "script-src https://www.googletagmanager.com"}} }

        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "a host our policy does not allow" do
        let(:blocked_uri) { "https://images.simplycodes.com/tracker.gif" }
        let(:effective_directive) { "img-src" }

        it "forwards" do
          perform
          expect(forwarded_blocked_uri).to eq blocked_uri
        end
      end

      context "a font from a third party" do
        # Coupon and citation extensions inject page-level <link>s
        let(:blocked_uri) { "https://images.simplycodes.com/fonts/CircularXXWeb-Medium.woff2" }
        let(:effective_directive) { "font-src" }

        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "a font from our own origin" do
        let(:blocked_uri) { "https://bikeindex.org/assets/inter.woff2" }
        let(:effective_directive) { "font-src" }

        it "forwards" do
          perform
          expect(forwarded_blocked_uri).to eq blocked_uri
        end
      end

      context "same-origin blocked-uri our policy would allow" do
        # 'self' permits it, so this is a redirect to a target the browser won't name
        let(:blocked_uri) { "https://bikeindex.org/payments" }
        let(:document_uri) { "https://bikeindex.org/donate" }
        let(:effective_directive) { "connect-src" }

        it "forwards" do
          perform
          expect(forwarded_blocked_uri).to eq blocked_uri
        end
      end

      context "malformed body" do
        ["not json", "null", "123", {"csp-report" => 5}.to_json].each do |raw_body|
          it "does not forward for #{raw_body.inspect}" do
            perform(raw_body)
            expect(forwarded).to be_empty
          end
        end
      end
    end
  end
end
