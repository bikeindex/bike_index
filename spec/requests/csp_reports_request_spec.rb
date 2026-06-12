require "rails_helper"

base_url = "/csp_reports"
RSpec.describe CspReportsController, type: :request do
  describe "create" do
    let(:report) { {"csp-report" => {"blocked-uri" => blocked_uri, "document-uri" => "https://bikeindex.org/bikes/1", "effective-directive" => "script-src"}} }
    let(:blocked_uri) { "https://evil.example.com/x.js" }
    let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/148.0.0.0 Safari/537.36" }
    let(:query) { "api_key=xxx&report_only=false&env=test" }

    def post_report
      post "/csp_reports?#{query}", params: report.to_json,
        headers: {"CONTENT_TYPE" => "application/csp-report", "HTTP_USER_AGENT" => user_agent}
    end

    it "forwards a real violation to Honeybadger" do
      post_report
      expect(response.status).to eq(204)
      expect(ForwardCspReportJob).to have_enqueued_sidekiq_job(report.to_json, query)
    end

    context "browser-extension noise" do
      let(:blocked_uri) { "chrome-extension://0dca8e62/fonts/Inter-Variable.ttf" }
      it "drops the report" do
        post_report
        expect(response.status).to eq(204)
        expect(ForwardCspReportJob.jobs.count).to eq 0
      end
    end

    context "in-app browser" do
      let(:user_agent) { "Mozilla/5.0 (Linux; Android 12) Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/488.0.0.78.79;]" }
      it "drops the report" do
        post_report
        expect(ForwardCspReportJob.jobs.count).to eq 0
      end
    end

    context "translate proxy frame" do
      let(:blocked_uri) { "https://www.google.co.id/" }
      it "drops the report" do
        post_report
        expect(ForwardCspReportJob.jobs.count).to eq 0
      end
    end

    context "read-aloud data: media" do
      let(:report) { {"csp-report" => {"blocked-uri" => "data", "effective-directive" => "media-src"}} }
      it "drops the report" do
        post_report
        expect(ForwardCspReportJob.jobs.count).to eq 0
      end
    end

    context "malformed body" do
      it "returns 204 without enqueuing" do
        post "#{base_url}?#{query}", params: "not json",
          headers: {"CONTENT_TYPE" => "application/csp-report"}
        expect(response.status).to eq(204)
        expect(ForwardCspReportJob.jobs.count).to eq 0
      end
    end
  end
end
