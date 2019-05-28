require "spec_helper"

describe "Organized::AmbassadorDashboardsController" do
  let(:base_url) { "/o/#{organization.to_param}/ambassador_dashboard" }
  # Request specs don't have cookies so we need to stub stuff if we're in request specs
  # This is suboptimal, but hey, it gets us to request specs for now
  before { allow(User).to receive(:from_auth) { user } }
  let(:organization) { FactoryBot.create(:organization_ambassador) }

  context "given an unauthenticated user" do
    let(:user) { FactoryBot.create(:user) }
    describe "index" do
      let(:organization) { FactoryBot.create(:organization) }
      it "redirects to the user homepage" do
        get base_url
        expect(response).to redirect_to(/user_home/)
      end
    end
  end

  context "given an authenticated non-ambassador" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    describe "index" do
      it "redirects the user's homepage" do
        get base_url
        expect(response).to redirect_to organization_bikes_path(organization_id: organization)
      end
    end
  end

  context "given an authenticated ambassador" do
    let(:user) { FactoryBot.create(:ambassador, organization: organization) }

    describe "show" do
      it "renders the ambassador dashboard" do
        get base_url
        expect(response.status).to eq(200)
        expect(assigns(:ambassadors).count).to eq(1)
        expect(response).to render_template(:show)
      end
    end

    describe "resources" do
      it "renders the ambassador resources" do
        get "#{base_url}/resources"
        expect(response.status).to eq(200)
        expect(response).to render_template(:resources)
      end
    end

    describe "getting_started" do
      it "renders the ambassador resources" do
        get "#{base_url}/getting_started"
        expect(response.status).to eq(200)
        expect(response).to render_template(:getting_started)
      end
    end
  end
end

