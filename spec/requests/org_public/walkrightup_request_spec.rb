require "rails_helper"

RSpec.describe OrgPublic::WalkrightupController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/walkrightup" }
  let(:current_organization) { FactoryBot.create(:organization) }

  it "redirects" do
    expect {
      get "/some-known-organization/walkrightup"
    }.to raise_error(ActiveRecord::RecordNotFound)
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
        get "/#{current_organization.to_param}/WalkRightUp" # test the casing
        expect(response.status).to eq(200)
        expect(response).to render_template :show
        expect(assigns(:current_location)).to eq location
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
        expect(assigns(:appointment).id).to be_blank # Because it's a new appointment

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
      context "with appointment_token" do
        let(:appointment) { FactoryBot.create(:appointment, organization: current_organization) }
        it "renders with the appointment" do
          expect(appointment.location_id).to eq location.id
          expect(appointment.in_line?).to be_truthy
          get "#{base_url}?appointment_token=#{appointment.link_token}"
          expect(response.status).to eq(200)
          expect(response).to render_template :show
          expect(assigns(:current_location)).to eq location
          expect(assigns(:current_organization)).to eq current_organization
          expect(assigns(:appointment).id).to eq appointment.id
        end
        context "appointment is not in_line" do
          let(:appointment) { FactoryBot.create(:appointment, organization: current_organization, status: "being_helped") }
          it "renders with a new appointment" do
            expect(appointment.location_id).to eq location.id
            get "#{base_url}?appointment_token=#{appointment.link_token}"
            expect(response.status).to eq(200)
            expect(response).to render_template :show
            expect(assigns(:current_location)).to eq location
            expect(assigns(:current_organization)).to eq current_organization
            expect(assigns(:appointment).id).to be_blank
          end
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
