require "rails_helper"

# Need controller specs to test setting session
RSpec.describe Organized::ManagesController, type: :controller do
  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "show" do
      it "renders, sets active organization" do
        session[:passive_organization_id] = "XXXYYY"
        get :show, params: { organization_id: organization.to_param }
        expect(response.status).to eq(200)
        expect(response).to render_template :show
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end
    describe "schedule" do
      let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["appointments"]) }
      let!(:location) { FactoryBot.create(:location, organization: organization) }
      let!(:location2) { FactoryBot.create(:location, organization: organization) }
      context "not passed location" do
        it "doesn't set passive_organization_location" do
          expect(organization.default_location).to eq location
          get :schedule, params: { organization_id: organization.to_param }
          expect(response.status).to eq(200)
          expect(response).to render_template :schedule
          expect(assigns(:current_organization)).to eq organization
          expect(assigns(:passive_organization)).to eq organization
          expect(session[:passive_organization_id]).to eq organization.id

          expect(assigns(:location)).to eq location
          expect(assigns(:current_organization_location)).to eq location
          expect(session[:passive_organization_location_id]).to eq "0"
        end
      end
      context "passed location" do
        it "sets passive_organization_location" do
          session[:passive_organization_location_id] = location.id.to_s
          get :schedule, params: { organization_id: organization.to_param, organization_location_id: location2.id }
          expect(response.status).to eq(200)
          expect(response).to render_template :schedule
          expect(assigns(:location).id).to eq location2.id
          expect(assigns(:current_organization_location).id).to eq location2.id
          expect(session[:passive_organization_location_id]).to eq location2.id
        end
      end
      context "passive location set" do
        it "uses passive, doesn't reset passive_organization_location" do
          session[:passive_organization_location_id] = location2.id
          get :schedule, params: { organization_id: organization.to_param }
          expect(response.status).to eq(200)
          expect(response).to render_template :schedule
          expect(assigns(:location).id).to eq location2.id
          expect(assigns(:current_organization_location).id).to eq location2.id
          expect(session[:passive_organization_location_id]).to eq location2.id
        end
        context "not matching passive location set" do
          it "resets passive_organization_location" do
            session[:passive_organization_location_id] = FactoryBot.create(:location).id
            get :schedule, params: { organization_id: organization.to_param }
            expect(response.status).to eq(200)
            expect(response).to render_template :schedule
            expect(assigns(:location)).to eq location
            expect(assigns(:current_organization_location).id).to eq location.id
            expect(session[:passive_organization_location_id]).to eq "0"
          end
        end
      end
    end
  end
end
