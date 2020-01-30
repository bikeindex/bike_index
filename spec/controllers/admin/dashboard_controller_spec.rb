require "rails_helper"

RSpec.describe Admin::DashboardController, type: :controller do
  describe "index" do
    context "not logged in" do
      it "redirects" do
        get :index
        expect(response.code).to eq("302")
        expect(response).to redirect_to(root_url)
      end
    end
    context "non-admin" do
      include_context :logged_in_as_organization_admin
      it "redirects" do
        get :index
        expect(response.code).to eq("302")
        expect(response).to redirect_to organization_root_path(organization_id: user.default_organization.to_param)
      end
    end
  end

  context "logged in as admin" do
    include_context :logged_in_as_super_admin

    describe "index (also timezone setting tests)" do
      before do
        # Create the things we look at, so we ensure it doesn't break
        FactoryBot.create(:ownership)
        FactoryBot.create(:user)
        FactoryBot.create(:organization)
      end
      let(:timezone) { "America/Los_Angeles" }
      let(:time_range_start) { Time.now.in_time_zone(timezone).beginning_of_day - 7.days }
      it "renders, sets timezone from params" do
        get :index, params: { timezone: timezone }
        expect(response.code).to eq "200"
        expect(response).to render_template(:index)
        expect(session[:timezone]).to eq timezone
        expect(assigns(:time_range).first).to be_within(2.seconds).of time_range_start
        expect(Time.zone).to eq TimeParser::DEFAULT_TIMEZONE
      end
      context "timezone set in session, not passed" do
        let(:timezone) { "Amsterdam" } # UTC + 1
        it "uses session timezone" do
          session[:timezone] = timezone
          get :index
          expect(response.code).to eq "200"
          expect(response).to render_template(:index)
          expect(session[:timezone]).to eq timezone
          expect(assigns(:time_range).first).to be_within(2.seconds).of time_range_start
          expect(Time.zone).to eq TimeParser::DEFAULT_TIMEZONE
        end
      end
      context "passing nonsense timezone" do
        it "doesn't set the timezone" do
          session[:timezone] = timezone
          get :index, params: { timezone: "party-zone" }
          expect(response.code).to eq "200"
          expect(response).to render_template(:index)
          expect(session[:timezone]).to be_blank
          expect(Time.zone).to eq TimeParser::DEFAULT_TIMEZONE
        end
      end
    end

    describe "scheduled_jobs" do
      it "renders" do
        get :scheduled_jobs
        expect(response.code).to eq "200"
        expect(response).to render_template(:scheduled_jobs)
      end
    end

    describe "maintenance" do
      it "renders" do
        FactoryBot.create(:manufacturer, name: "other")
        FactoryBot.create(:ctype, name: "other")
        BParam.create(creator_id: user.id)
        get :maintenance
        expect(response.code).to eq "200"
        expect(response).to render_template(:maintenance)
      end
    end

    describe "tsvs" do
      it "renders and assigns tsvs" do
        t = Time.current
        FileCacheMaintainer.reset_file_info("current_stolen_bikes.tsv", t)
        # tsvs = [{ filename: 'current_stolen_bikes.tsv', updated_at: t.to_i.to_s, description: 'Approved Stolen bikes' }]
        blacklist = %w(1010101 2 4 6)
        FileCacheMaintainer.reset_blacklist_ids(blacklist)
        get :tsvs
        expect(response.code).to eq("200")
        # assigns(:tsvs).should eq(tsvs)
        expect(assigns(:blacklist).include?("2")).to be_truthy
      end
    end

    describe "update_tsv_blacklist" do
      it "renders and updates" do
        ids = "\n1\n2\n69\n200\n22222\n\n\n"
        put :update_tsv_blacklist, params: { blacklist: ids }
        expect(FileCacheMaintainer.blacklist).to eq([1, 2, 69, 200, 22222].map(&:to_s))
      end
    end
  end
end
