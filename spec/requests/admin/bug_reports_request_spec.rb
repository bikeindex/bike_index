require "rails_helper"

base_url = "/admin/bug_reports"
RSpec.describe Admin::BugReportsController, type: :request do
  let(:bug_report) { FactoryBot.create(:bug_report, tags: ["parking"]) }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      expect(bug_report).to be_present
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end

    context "json" do
      let(:target_json) do
        bug_report.as_json(only: %w[id user_id email subject body tags github_pull_request
          is_member is_paid_organization is_paid_organization_staff created_at updated_at])
      end

      it "renders a paginated list" do
        expect(bug_report).to be_present
        get "#{base_url}.json", params: {per_page: 1}
        expect(response.status).to eq(200)
        expect(json_result["bug_reports"]).to eq([target_json])
        expect(json_result).to match(hash_including("page" => 1, "per_page" => 1))
      end
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{bug_report.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end

  describe "update" do
    it "updates from the form, splitting tags" do
      patch "#{base_url}/#{bug_report.to_param}", params: {
        bug_report: {tags: "parking, Search", github_pull_request: "3805"}
      }
      expect(response).to redirect_to(admin_bug_report_path(bug_report))
      expect(flash[:success]).to be_present
      expect(bug_report.reload).to have_attributes(tags: %w[parking search], github_pull_request: 3805)
    end

    context "json" do
      it "updates" do
        patch "#{base_url}/#{bug_report.to_param}", params: {
          bug_report: {tags: %w[search broken], github_pull_request: 3805}
        }, as: :json
        expect(response.status).to eq(200)
        expect(bug_report.reload).to have_attributes(tags: %w[broken search], github_pull_request: 3805)
        expect(json_result.dig("bug_report", "tags")).to eq(%w[broken search])
      end
    end
  end

  describe "assign_tags" do
    let!(:bug_report_unselected) { FactoryBot.create(:bug_report) }

    it "adds the tags to the selected bug reports" do
      post "#{base_url}/assign_tags", params: {
        tags: "search, Broken",
        bug_reports_selected: {bug_report.id.to_s => bug_report.id}
      }
      expect(response).to redirect_to(admin_bug_reports_path)
      expect(flash[:success]).to be_present
      expect(bug_report.reload.tags).to eq(%w[broken parking search])
      expect(bug_report_unselected.reload.tags).to eq([])
    end

    context "without a tag" do
      it "does not update" do
        post "#{base_url}/assign_tags", params: {
          tags: "", bug_reports_selected: {bug_report.id.to_s => bug_report.id}
        }
        expect(response).to redirect_to(admin_bug_reports_path)
        expect(flash[:error]).to be_present
        expect(bug_report.reload.tags).to eq(["parking"])
      end
    end
  end
end
