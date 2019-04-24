require "spec_helper"

describe Admin::DashboardController do
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
        expect(response).to redirect_to organization_bikes_path(organization_id: user.default_organization.to_param)
      end
    end
  end

  context "logged in as admin" do
    include_context :logged_in_as_super_admin
    describe "index" do
      it "renders" do
        # Create the things we look at, so that we ensure it doesn't break
        FactoryBot.create(:ownership)
        FactoryBot.create(:user)
        FactoryBot.create(:organization)
        get :index
        expect(response.code).to eq "200"
        expect(response).to render_template(:index)
      end
    end

    describe "invitations" do
      it "renders" do
        user = FactoryBot.create(:admin)
        set_current_user(user)
        BParam.create(creator_id: user.id)
        get :invitations
        expect(response.code).to eq "200"
        expect(response).to render_template(:invitations)
      end
    end

    describe "maintenance" do
      it "renders" do
        FactoryBot.create(:manufacturer, name: "other")
        FactoryBot.create(:ctype, name: "other")
        user = FactoryBot.create(:admin)
        set_current_user(user)
        BParam.create(creator_id: user.id)
        get :maintenance
        expect(response.code).to eq "200"
        expect(response).to render_template(:maintenance)
      end
    end

    describe "tsvs" do
      it "renders and assigns tsvs" do
        user = FactoryBot.create(:admin)
        set_current_user(user)
        t = Time.now
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
        user = FactoryBot.create(:admin)
        set_current_user(user)
        ids = "\n1\n2\n69\n200\n22222\n\n\n"
        put :update_tsv_blacklist, blacklist: ids
        expect(FileCacheMaintainer.blacklist).to eq([1, 2, 69, 200, 22222].map(&:to_s))
      end
    end
  end
end
