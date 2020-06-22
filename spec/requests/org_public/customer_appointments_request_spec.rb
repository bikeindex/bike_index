require "rails_helper"

RSpec.describe OrgPublic::CustomerAppointmentsController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/customer_appointments" }
  let(:appointment) { FactoryBot.create(:appointment, location: location, organization: current_organization) }
  let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
  let(:current_organization) { location.organization }
  let(:appointment_configuration) { location.appointment_configuration }

  describe "show" do
    it "redirects if passed token" do
      expect(location.virtual_line_on?).to be_truthy
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
  end

  describe "set_current" do
    it "redirects" do
      post "#{base_url}/set_current", params: { token: appointment.link_token }
      expect(assigns(:current_location)).to eq location
      expect(assigns(:current_organization)).to eq current_organization
      expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
      expect(flash).to be_blank
      expect(response).to redirect_to organization_customer_line_path(organization_id: current_organization.to_param, location_id: location.to_param)
    end
  end

  describe "create" do
    let(:appointment_params) { { name: "Sarah h.", email: "something@stuff.com", reason: "Service", location_id: location.id } }
    it "creates and assigns the appointment" do
      current_organization.reload
      location.reload
      expect(current_organization.appointments.count).to eq 0
      expect(location.appointments.count).to eq 0
      expect(appointment_configuration.reasons.include?(appointment_params[:reason])).to be_truthy
      Sidekiq::Worker.clear_all
      expect do
        post base_url, params: { organization_id: current_organization.to_param, appointment: appointment_params }
        pp response.body
      end.to change(Appointment, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 1
      location.reload
      current_organization.reload
      expect(location.appointments.count).to eq 1
      # expect(current_organization.appointments.count).to eq 1
      new_appointment = location.appointments.last

      expect(assigns(:current_appointment)).to eq new_appointment
      expect(response).to redirect_to(organization_customer_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
      expect(flash[:success]).to be_present

      expect(new_appointment.status).to eq "waiting"
      expect(new_appointment.name).to eq appointment_params[:name]
      expect(new_appointment.email).to eq appointment_params[:email]
      expect(new_appointment.reason).to eq appointment_params[:reason]
      expect(new_appointment.location_id).to eq location.id
      expect(new_appointment.organization_id).to eq current_organization.id
    end
  end
end
