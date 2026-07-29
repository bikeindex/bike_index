require "rails_helper"

RSpec.describe ForwardCspReportJob, type: :job do
  let(:blocked_uri) { "https://evil.example.com/x.js" }
  let(:report) { {"csp-report" => {"blocked-uri" => blocked_uri, "document-uri" => "https://bikeindex.org/bikes/1", "effective-directive" => "script-src"}} }
  let(:body) { report.to_json }
  let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/148.0.0.0 Safari/537.36" }
  let(:forwarded) { [] }

  before { stub_const("ForwardCspReportJob::HONEYBADGER_CSP_API_KEY", "abc123") }

  describe "#perform" do
    before do
      WebMock.stub_request(:post, /api\.honeybadger\.io/).to_return {
        forwarded << true
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
        expect(forwarded).to contain_exactly(true)
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
        let(:report) { {"csp-report" => {"blocked-uri" => "data", "effective-directive" => "media-src"}} }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
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
