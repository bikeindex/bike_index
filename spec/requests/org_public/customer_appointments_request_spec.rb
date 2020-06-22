require "rails_helper"

RSpec.describe OrgPublic::CustomerAppointmentsController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/customer_appointments" }
  let(:appointment) { FactoryBot.create(:appointment) }
  let(:location) { appointment.location }
  let(:current_organization) { location.organization }

  it "renders if passed token" do
    expect(location.virtual_line_on?).to be_falsey
    expect(appointment.link_token).to be_present
    get "#{base_url}/#{appointment.id}"
    expect(response).to redirect_to organization_customer_line_path(organization_id: current_organization.to_param)
    expect(flash[:error]).to be_present

    get "#{base_url}/#{appointment.link_token}"
    expect(assigns(:current_location)).to eq location
    expect(assigns(:current_organization)).to eq current_organization
    expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
    expect(flash).to be_blank
    expect(response).to redirect_to organization_customer_line_path(organization_id: current_organization.to_param, location_id: location.to_param)
  end

  describe "create" do
    let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
    let(:current_organization) { location.organization }
    let(:appointment_params) do
      {}
    end

    xit "assigns the appointment to session" do
      current_organization.reload
      location.reload
      expect(current_organization.appointments.count).to eq 0
      expect(location.appointments.count).to eq 0
      pp appointment_params
      expect do
        post base_url, params: { organization_id: current_organization.to_param, appointment: appointment_params }
      end.to change(Appointment, :count).by 1

      expect(assigns(:current_appointment)).to eq appointment
      expect(session[:appointment_token]).to eq appointment.link_token
      expect(response).to redirect_to(organization_customer_line_path(organization_id: current_organization.to_param))
      expect(flash[:success]).to be_present
    end
  end
end
