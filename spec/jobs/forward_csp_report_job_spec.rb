require "rails_helper"

RSpec.describe ForwardCspReportJob, type: :job do
  let(:blocked_uri) { "https://evil.example.com/x.js" }
  let(:document_uri) { "https://bikeindex.org/bikes/1" }
  let(:report) { {"csp-report" => {"blocked-uri" => blocked_uri, "document-uri" => document_uri, "effective-directive" => "script-src"}} }
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
        let(:blocked_uri) { "https://evil.example.com/x.js?label=WADeCPKg7gYQtvfc0wM" }

        it "forwards it normalized" do
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

      context "a report CspReport treats as noise" do
        let(:blocked_uri) { "chrome-extension://0dca8e62/fonts/Inter-Variable.ttf" }
        it "does not forward" do
          perform
          expect(forwarded).to be_empty
        end
      end

      context "malformed body" do
        it "does not forward" do
          perform("not json")
          expect(forwarded).to be_empty
        end
      end
    end
  end
end
