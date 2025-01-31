require "rails_helper"

RSpec.describe Admin::DashboardController, type: :request do
  describe "index" do
    context "not logged in" do
      it "redirects" do
        get "/admin"
        expect(response.code).to eq("302")
        expect(response).to redirect_to(root_url)
      end
    end
    context "non-admin" do
      include_context :request_spec_logged_in_as_organization_admin
      it "redirects" do
        get "/admin"
        expect(response.code).to eq("302")
        expect(response).to redirect_to organization_root_path(organization_id: current_user.default_organization.to_param)
      end
    end
  end

  context "logged in as admin" do
    include_context :request_spec_logged_in_as_superuser

    describe "index (also timezone setting tests)" do
      let!(:bike) { FactoryBot.create(:bike, :with_ownership) }
      before do
        # Create the things we look at, so we ensure it doesn't break
        FactoryBot.create(:user)
        FactoryBot.create(:organization)
      end
      let(:timezone) { "America/Los_Angeles" }
      let(:time_range_start) { Time.now.in_time_zone(timezone).beginning_of_day - 7.days }
      it "renders, sets timezone from params and skips likely_spam by default" do
        Organization.example && Cgroup.additional_parts # Read replica
        bike2 = FactoryBot.create(:bike, :with_ownership, likely_spam: true)
        get "/admin", params: {timezone: timezone}
        expect(response.code).to eq "200"
        expect(response).to render_template(:index)
        expect(session[:timezone]).to eq timezone
        expect(assigns(:time_range).first).to be_within(2.seconds).of time_range_start
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
        expect(Time.zone).to eq TimeParser::DEFAULT_TIME_ZONE
        # If current user has no_hide_spam, it shows likely_spam though
        SuperuserAbility.create(user: current_user, su_options: [:no_hide_spam])
        get "/admin", params: {timezone: timezone}
        expect(response.code).to eq "200"
        expect(response).to render_template(:index)
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, bike2.id])
      end
      context "passing nonsense timezone" do
        it "doesn't set the timezone" do
          Organization.example && Cgroup.additional_parts # Read replica
          get "/admin", params: {timezone: "party-zone"}
          expect(response.code).to eq "200"
          expect(response).to render_template(:index)
          expect(session[:timezone]).to be_blank
          expect(Time.zone).to eq TimeParser::DEFAULT_TIME_ZONE
        end
      end
    end

    describe "credibility_badges" do
      it "renders" do
        get "/admin/credibility_badges"
        expect(response.code).to eq "200"
        expect(response).to render_template(:credibility_badges)
      end
    end

    describe "scheduled_jobs" do
      it "renders" do
        get "/admin/scheduled_jobs"
        expect(response.code).to eq "200"
        expect(response).to render_template(:scheduled_jobs)
      end
    end

    describe "autocomplete_status" do
      it "renders" do
        get "/admin/autocomplete_status"
        expect(response.code).to eq "200"
        expect(response).to render_template(:autocomplete_status)
      end
    end

    describe "maintenance" do
      it "renders" do
        Organization.example && Cgroup.additional_parts && Ctype.other # Read replica
        FactoryBot.create(:manufacturer, name: "other")
        BParam.create(creator_id: current_user.id)
        get "/admin/maintenance"
        expect(response.code).to eq "200"
        expect(response).to render_template(:maintenance)
      end
    end

    describe "tsvs" do
      it "renders and assigns tsvs" do
        t = Time.current
        FileCacheMaintainer.reset_file_info("current_stolen_bikes.tsv", t)
        # tsvs = [{ filename: 'current_stolen_bikes.tsv', updated_at: t.to_i.to_s, description: 'Approved Stolen bikes' }]
        blocklist = %w[1010101 2 4 6]
        FileCacheMaintainer.reset_blocklist_ids(blocklist)
        get "/admin/tsvs"
        expect(response.code).to eq("200")
        # assigns(:tsvs).should eq(tsvs)
        expect(assigns(:blocklist).include?("2")).to be_truthy
      end
    end

    describe "update_tsv_blocklist" do
      it "renders and updates" do
        ids = "\n1\n2\n69\n200\n22222\n\n\n"
        put "/admin/update_tsv_blocklist", params: {blocklist: ids}
        expect(FileCacheMaintainer.blocklist).to eq([1, 2, 69, 200, 22222].map(&:to_s))
      end
    end
  end
end
