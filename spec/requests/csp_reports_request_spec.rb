require "rails_helper"

base_url = "/csp_reports"
RSpec.describe CspReportsController, type: :request do
  describe "create" do
    let(:report) { {"csp-report" => {"blocked-uri" => blocked_uri, "document-uri" => "https://bikeindex.org/bikes/1", "effective-directive" => "script-src"}} }
    let(:blocked_uri) { "https://evil.example.com/x.js" }
    let(:user_agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/148.0.0.0 Safari/537.36" }

    def post_report
      post "/csp_reports", params: report.to_json,
        headers: {"CONTENT_TYPE" => "application/csp-report", "HTTP_USER_AGENT" => user_agent}
    end

    it "forwards a real violation to Honeybadger" do
      post_report
      expect(response.status).to eq(204)
      expect(ForwardCspReportJob).to have_enqueued_sidekiq_job(report.to_json, nil)
    end

    context "with a signed-in user" do
      include_context :request_spec_logged_in_as_user
      it "captures the user id server-side, ignoring client-supplied context" do
        post "#{base_url}?context[user_id]=999", params: report.to_json,
          headers: {"CONTENT_TYPE" => "application/csp-report", "HTTP_USER_AGENT" => user_agent}
        expect(response.status).to eq(204)
        expect(ForwardCspReportJob).to have_enqueued_sidekiq_job(report.to_json, current_user.id)
      end
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
      ["not json", "null", "123", {"csp-report" => 5}.to_json].each do |raw_body|
        it "returns 204 without enqueuing for #{raw_body.inspect}" do
          post base_url, params: raw_body,
            headers: {"CONTENT_TYPE" => "application/csp-report"}
          expect(response.status).to eq(204)
          expect(ForwardCspReportJob.jobs.count).to eq 0
        end
      end
    end

    describe "rack_attack" do
      include_context :rack_attack

      it "throttles reports past the csp limit" do
        throttled = rack_attack_throttled_response(limit: Rack::Attack::CSP_REPORTS_MAX_REQUESTS) do
          post_report
          response
        end
        expect(throttled).to have_http_status(:too_many_requests)
      end

      # The dedicated bucket is excluded from the global throttle, so a report
      # flood can't consume a user's navigation budget.
      it "does not count against the global per-IP throttle" do
        Rack::Attack::MAX_REQUESTS_PER_TWENTY.times { post_report }
        get "/vendor_signup" # a normal (non-excluded) path that redirects without rendering
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end
end
