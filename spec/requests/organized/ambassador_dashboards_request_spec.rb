require "rails_helper"

RSpec.describe Organized::AmbassadorDashboardsController, type: :request do
  include_context :logged_in_as_ambassador
  let(:organization) { FactoryBot.create(:organization_ambassador) }

  context "given an unauthenticated user" do
    let(:user) { FactoryBot.create(:user) }
    describe "index" do
      let(:organization) { FactoryBot.create(:organization) }
      it "redirects to the user homepage" do
        get organization_ambassador_dashboard_path(organization)
        expect(response).to redirect_to(/user_home/)
      end
    end
  end

  context "given an authenticated non-ambassador" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    describe "index" do
      it "redirects to organization root path" do
        get organization_ambassador_dashboard_path(organization)
        expect(response).to redirect_to organization_root_path(organization_id: organization)
      end
    end
  end

  context "given an authenticated ambassador" do
    let(:user) { FactoryBot.create(:ambassador, organization: organization) }

    describe "show" do
      it "renders the ambassador dashboard" do
        FactoryBot.create_list(:ambassador_task, 2)
        FactoryBot.create_list(:ambassador, 2, organization: organization)

        get organization_ambassador_dashboard_path(organization)

        expect(response.status).to eq(200)
        expect(assigns(:ambassadors).count).to eq(3)
        expect(response).to render_template(:show)
      end
      context "has not accepted vendor terms" do
        let(:user) { FactoryBot.create(:ambassador, accept_vendor_terms_of_service: false) }
        it "redirects to accept the terms" do
          get "/o/#{organization.slug}/ambassador_dashboard"
          expect(response).to redirect_to accept_vendor_terms_path
        end
      end
    end

    describe "resources" do
      it "renders the ambassador resources" do
        get resources_organization_ambassador_dashboard_path(organization)
        expect(response.status).to eq(200)
        expect(response).to render_template(:resources)
      end
    end

    describe "getting_started" do
      it "renders the ambassador resources" do
        get getting_started_organization_ambassador_dashboard_path(organization)
        expect(response.status).to eq(200)
        expect(response).to render_template(:getting_started)
      end
    end
  end

  context "given a non-ambassador super admin" do
    let(:user) { FactoryBot.create(:admin) }

    describe "show" do
      it "renders the ambassador dashboard with ambassadors list" do
        FactoryBot.create_list(:ambassador_task, 2)
        FactoryBot.create_list(:ambassador, 2, organization: organization)

        get organization_ambassador_dashboard_path(organization)

        expect(response.status).to eq(200)
        expect(assigns(:ambassadors).count).to eq(2)
        expect(assigns(:suggested_activities).count).to eq(2)
        expect(assigns(:completed_activities).count).to eq(0)
        expect(response).to render_template(:show)
      end
    end

    describe "resources" do
      it "renders the ambassador resources template" do
        get resources_organization_ambassador_dashboard_path(organization)
        expect(response.status).to eq(200)
        expect(response).to render_template(:resources)
      end
    end

    describe "getting_started" do
      it "renders the ambassador getting started template" do
        get getting_started_organization_ambassador_dashboard_path(organization)
        expect(response.status).to eq(200)
        expect(response).to render_template(:getting_started)
      end
    end
  end
end
