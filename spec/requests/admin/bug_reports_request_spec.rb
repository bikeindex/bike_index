require "rails_helper"

base_url = "/admin/bug_reports"
RSpec.describe Admin::BugReportsController, type: :request do
  let(:bug_report) { FactoryBot.create(:bug_report, tags: ["parking"]) }
  let(:target_json) do
    bug_report.as_json(only: %w[id user_id email from_name receiver subject body tags status github_pull_request
      is_member is_paid_organization is_paid_organization_staff received_at created_at updated_at])
      .merge("images" => [])
  end
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      expect(bug_report).to be_present
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end

    context "json" do
      it "renders a paginated list" do
        expect(bug_report).to be_present
        get "#{base_url}.json", params: {per_page: 1, search_status: "all"}
        expect(response.status).to eq(200)
        expect(json_result["bug_reports"]).to eq([target_json])
        expect(json_result).to match(hash_including("page" => 1, "per_page" => 1))
      end
    end

    context "with query" do
      let!(:bug_report_other) { FactoryBot.create(:bug_report, subject: "Payments page timeout") }

      it "full text searches" do
        expect(bug_report).to be_present
        get "#{base_url}.json", params: {query: "payments timeout", search_status: "all"}
        expect(json_result["bug_reports"].map { it["id"] }).to eq([bug_report_other.id])
      end
    end

    context "sorted by status" do
      let!(:bug_report_resolved) { FactoryBot.create(:bug_report, status: :resolved) }
      let!(:bug_report_ignored) { FactoryBot.create(:bug_report, status: :ignored) }

      it "orders by the enum integer" do
        expect(bug_report.status).to eq "unprioritized"
        expected = [bug_report, bug_report_resolved, bug_report_ignored]
          .sort_by { BugReport.statuses[it.status] }.map(&:id)
        get "#{base_url}.json", params: {sort: "status", direction: "asc", search_status: "all"}
        expect(json_result["bug_reports"].map { it["id"] }).to eq(expected)
      end
    end

    context "with search_status" do
      let!(:bug_report_investigate) { FactoryBot.create(:bug_report, status: :investigate_priority_high) }
      let!(:bug_report_resolved) { FactoryBot.create(:bug_report, status: :resolved) }

      it "defaults to the investigate statuses, including untriaged reports" do
        expect(bug_report.status).to eq "unprioritized"
        get "#{base_url}.json"
        expect(json_result["bug_reports"].map { it["id"] })
          .to match_array([bug_report.id, bug_report_investigate.id])
        expect(json_result["bug_reports"].map { it["id"] }).not_to include(bug_report_resolved.id)
      end

      it "filters to a single status" do
        get "#{base_url}.json", params: {search_status: "resolved"}
        expect(json_result["bug_reports"].map { it["id"] }).to eq([bug_report_resolved.id])
      end

      it "shows everything with all" do
        expect(bug_report).to be_present
        get "#{base_url}.json", params: {search_status: "all"}
        expect(json_result["bug_reports"].map { it["id"] })
          .to match_array([bug_report.id, bug_report_investigate.id, bug_report_resolved.id])
      end
    end

    context "with search_receiver" do
      let!(:bug_report_support) { FactoryBot.create(:bug_report, receiver: "support@bikeindex.org") }

      it "filters by the receiver" do
        expect(bug_report.receiver).to eq "contact@bikeindex.org"
        get "#{base_url}.json", params: {search_receiver: "support@bikeindex.org", search_status: "all"}
        expect(json_result["bug_reports"].map { it["id"] }).to eq([bug_report_support.id])
      end

      it "matches nothing for a receiver no bug report has" do
        expect(bug_report).to be_present
        get "#{base_url}.json", params: {search_receiver: "nonsense@bikeindex.org", search_status: "all"}
        expect(json_result["bug_reports"]).to eq([])
      end

      it "names the search in the count detail" do
        get base_url, params: {search_receiver: "support@bikeindex.org", search_status: "all"}
        expect(response.body).to match(/1<\/strong>\s*Matching/)
        expect(response.body).to include("receiver: <code>support@bikeindex.org</code>")
      end
    end

    context "with search_email" do
      let!(:bug_report_other) { FactoryBot.create(:bug_report, email: "someone@example.com") }

      it "filters by a partial, case insensitive match" do
        expect(bug_report.email).to_not eq bug_report_other.email
        get "#{base_url}.json", params: {search_email: "SOMEONE@example", search_status: "all"}
        expect(json_result["bug_reports"].map { it["id"] }).to eq([bug_report_other.id])
      end
    end

    context "with search_membership" do
      let!(:bug_report_paid) { FactoryBot.create(:bug_report, is_paid_organization: true) }

      it "filters by the membership snapshot" do
        expect(bug_report.is_paid_organization).to be_falsey
        get "#{base_url}.json", params: {search_membership: "paid_organization", search_status: "all"}
        expect(json_result["bug_reports"].map { it["id"] }).to eq([bug_report_paid.id])
      end

      it "ignores an unknown membership filter" do
        expect(bug_report).to be_present
        get "#{base_url}.json", params: {search_membership: "nonsense", search_status: "all"}
        expect(json_result["bug_reports"].map { it["id"] }).to match_array([bug_report.id, bug_report_paid.id])
      end
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{bug_report.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end

    context "json" do
      it "renders the bug report" do
        get "#{base_url}/#{bug_report.to_param}.json"
        expect(response.status).to eq(200)
        expect(json_result["bug_report"]).to eq(target_json)
      end

      context "with an attached image" do
        before do
          bug_report.images.attach(io: StringIO.new("fake image"), filename: "broken.png",
            content_type: "image/png")
        end

        it "renders each image with a url that doesn't expire" do
          get "#{base_url}/#{bug_report.to_param}.json"
          expect(json_result.dig("bug_report", "images")).to eq([{
            "filename" => "broken.png", "byte_size" => 10, "content_type" => "image/png",
            "url" => BlobUrl.for(bug_report.reload.images.first.blob)
          }])
        end
      end
    end

    context "with a user" do
      let(:bug_report) { FactoryBot.create(:bug_report, user: FactoryBot.create(:user)) }

      it "renders, linking to the user" do
        get "#{base_url}/#{bug_report.to_param}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(response.body).to include(admin_user_path(bug_report.user_id))
      end
    end
  end

  describe "update" do
    it "updates from the form, splitting tags" do
      patch "#{base_url}/#{bug_report.to_param}", params: {
        bug_report: {tags: "parking, Search", github_pull_request: "3805", status: "investigate_priority_high"}
      }
      expect(response).to redirect_to(admin_bug_report_path(bug_report))
      expect(flash[:success]).to be_present
      expect(bug_report.reload).to have_attributes(tags: %w[parking search], github_pull_request: 3805,
        status: "investigate_priority_high")
    end

    context "with an unknown status" do
      it "ignores it" do
        expect(bug_report.status).to eq "unprioritized"
        patch "#{base_url}/#{bug_report.to_param}", params: {bug_report: {status: "nonsense", tags: "parking"}}
        expect(response).to redirect_to(admin_bug_report_path(bug_report))
        expect(bug_report.reload).to have_attributes(status: "unprioritized", tags: ["parking"])
      end
    end

    context "session without a CSRF token" do
      include_context :test_csrf_token
      it "does not update" do
        patch "#{base_url}/#{bug_report.to_param}", params: {
          bug_report: {github_pull_request: "3805"}
        }
        expect(response.status).to eq 302
        expect(flash[:error]).to be_present
        expect(bug_report.reload.github_pull_request).to be_blank
      end
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

  describe "tag_chips" do
    it "renders a chip for each combobox value, verbatim so the combobox can remove it" do
      post "#{base_url}/tag_chips", params: {combobox_values: "search,Not Yet Normalized", for_id: "bug_report_tags"},
        as: :turbo_stream
      expect(response.status).to eq(200)
      expect(response.body.scan(/<span>([^<]+)<\/span>/).flatten).to eq(["search", "Not Yet Normalized"])
      expect(response.body).to include('data-hw-combobox-value-param="Not Yet Normalized"')
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

    context "without a selection" do
      it "does not update" do
        post "#{base_url}/assign_tags", params: {tags: "search"}
        expect(response).to redirect_to(admin_bug_reports_path)
        expect(flash[:error]).to be_present
        expect(bug_report.reload.tags).to eq(["parking"])
      end
    end
  end

  describe "authenticated with an API token" do
    let(:current_user) { false } # No session - the token is the authentication
    include_context :admin_doorkeeper_token
    include_context :test_csrf_token

    let(:url) { "#{base_url}.json" }
    include_examples "rejects_unauthorized_token"

    context "without a token or a session" do
      it "redirects" do
        get url
        expect(response.status).to eq 302
        expect(flash[:error]).to be_present
      end
    end

    context "token for a bug_reports superuser" do
      before { FactoryBot.create(:superuser_ability, user: token_user, controller_name: "bug_reports") }

      it "renders the index" do
        expect(bug_report).to be_present
        get url, params: token_param.merge(search_status: "all")
        expect(response.status).to eq 200
        expect(json_result["bug_reports"].map { it["id"] }).to eq([bug_report.id])
      end

      it "renders a single report" do
        get "#{base_url}/#{bug_report.to_param}.json", params: token_param
        expect(response.status).to eq 200
        expect(json_result.dig("bug_report", "id")).to eq bug_report.id
      end

      it "updates" do
        patch "#{base_url}/#{bug_report.to_param}", params: token_param.merge(
          bug_report: {tags: %w[search], github_pull_request: 3805}
        ), as: :json
        expect(response.status).to eq 200
        expect(bug_report.reload).to have_attributes(tags: %w[search], github_pull_request: 3805)
      end

      it "assigns tags" do
        post "#{base_url}/assign_tags", params: token_param.merge(
          tags: "search", bug_reports_selected: {bug_report.id.to_s => bug_report.id}
        )
        expect(response).to redirect_to(admin_bug_reports_path)
        expect(bug_report.reload.tags).to eq(%w[parking search])
      end
    end

    context "universal superuser token" do
      let(:token_user) { FactoryBot.create(:superuser) }
      it "renders the index" do
        get url, params: token_param
        expect(response.status).to eq 200
      end
    end

    # Presenting a token skips CSRF, so a forged write reaches the action with any
    # token at all - what stops it is that the token, not the session, authorizes
    context "a junk token forged onto a superuser's session" do
      let(:current_user) { FactoryBot.create(:superuser) }
      let(:forged_param) { {access_token: "not-a-real-token"} }

      it "does not update" do
        patch "#{base_url}/#{bug_report.to_param}", params: forged_param.merge(
          bug_report: {github_pull_request: "3805"}
        )
        expect(response.status).to eq 401
        expect(json_result[:error]).to eq "OAuth token required"
        expect(bug_report.reload.github_pull_request).to be_blank
      end

      it "does not assign tags" do
        post "#{base_url}/assign_tags", params: forged_param.merge(
          tags: "forged", bug_reports_selected: {bug_report.id.to_s => bug_report.id}
        )
        expect(response.status).to eq 401
        expect(json_result[:error]).to eq "OAuth token required"
        expect(bug_report.reload.tags).to eq(%w[parking])
      end
    end
  end
end
