require "rails_helper"

RSpec.describe ForwardCspReportJob, type: :job do
  let(:body) { {"csp-report" => {"blocked-uri" => "https://evil.example.com/x.js"}}.to_json }
  let(:forwarded) { [] }

  before { stub_const("ENV", ENV.to_hash.merge("HONEYBADGER_CSP_API_KEY" => "abc123")) }

  describe "#perform" do
    before do
      WebMock.stub_request(:post, /api\.honeybadger\.io/).to_return {
        forwarded << true
        {status: 201}
      }
    end
    after { WebMock.reset! }

    it "does not forward outside production, even with an API key" do
      described_class.new.perform(body, nil)
      expect(forwarded).to be_empty
    end

    context "in production" do
      before { allow(Rails).to receive(:env).and_return("production".inquiry) }

      it "forwards the report to Honeybadger" do
        described_class.new.perform(body, nil)
        expect(forwarded).to contain_exactly(true)
      end
    end
  end
end
