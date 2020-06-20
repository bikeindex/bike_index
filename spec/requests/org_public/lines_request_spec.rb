require "rails_helper"

RSpec.describe OrgPublic::LinesController, type: :request do
  let(:base_url) { "/partners/#{current_organization.to_param}/line" }
  let(:current_organization) { FactoryBot.create(:organization) }

  it "redirects" do
    expect do
      get "/partners/some-known-organization/line"
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  context "organization not found" do
    it "redirects" do
      expect(current_organization.appointment_functionality_enabled?).to be_falsey
      get base_url
      expect(flash[:error]).to be_present
      expect(response).to redirect_to root_url
    end
  end

  context "organization has virtual line" do
    let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, virtual_line_on: virtual_line_on) }
    let(:location) { appointment_configuration.location }
    let(:current_organization) { location.organization }
    let(:virtual_line_on) { false }

    it "redirects" do
      expect(current_organization.appointment_functionality_enabled?).to be_truthy
      expect(location.virtual_line_on?).to be_falsey
      get base_url
      expect(flash[:error]).to be_present
      expect(response).to redirect_to root_url
    end

    context "virtual_line_on" do
      let(:virtual_line_on) { true }
      it "renders" do
        expect(location.virtual_line_on?).to be_truthy
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :show
        expect(assigns(:current_location)).to eq location
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
        # But - if we remove the organization access, it fails
        appointment_configuration.update(virtual_line_on: false)
        location.reload
        expect(location.virtual_line_on?).to be_falsey
        get base_url
        expect(flash[:error]).to be_present
        expect(response).to redirect_to root_url
      end
      context "multiple location" do
        let!(:location_off) { FactoryBot.create(:location, organization: current_organization) }
        it "flash errors unless the location targeted is on" do
          expect(current_organization.appointment_functionality_enabled?).to be_truthy
          expect(location.virtual_line_on?).to be_truthy
          expect(location_off.virtual_line_on?).to be_falsey
          # Fails because location not found
          get base_url
          expect(flash[:error]).to match(/location/)
          expect(response).to redirect_to root_url
          # Fails because location not on
          get "#{base_url}?location_id=#{location_off.to_param}"
          expect(flash[:error]).to match(/location/i)
          expect(response).to redirect_to root_url
          # Fails because unknown location
          get "#{base_url}?location_id=somewhere-unknown"
          expect(flash[:error]).to match(/location/i)
          expect(response).to redirect_to root_url
          # succeeds
          get "#{base_url}?location_id=#{location.to_param}"
          expect(response.status).to eq(200)
          expect(response).to render_template :show
          expect(assigns(:current_location)).to eq location
          expect(assigns(:current_organization)).to eq current_organization
          expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
        end
      end
    end

    context "logged_in_as_organization_member" do
      include_context :request_spec_logged_in_as_organization_member
      let(:current_organization) { location.organization }
      describe "index" do
        it "renders" do
          expect(location.virtual_line_on?).to be_falsey
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template :show
          expect(assigns(:current_location)).to eq location
          expect(assigns(:current_organization)).to eq current_organization
          expect(assigns(:passive_organization)).to eq current_organization
          # it fails if passed an unknown location though
          get "#{base_url}?location_id=somewhere-unknown"
          expect(flash[:error]).to match(/location/i)
          expect(response).to redirect_to organization_root_path(organization_id: current_organization)
        end
      end
    end
  end
end
