require "rails_helper"

RSpec.describe Organized::AppointmentsController, type: :request do
  include_context :request_spec_logged_in_as_organization_member
  let(:base_url) { "/o/#{current_organization.to_param}/appointments" }
  let(:appointment) { FactoryBot.create(:appointment, status: status, location: location, organization: current_organization) }
  let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
  let(:current_organization) { location.organization }
  let(:appointment_configuration) { location.appointment_configuration }

  describe "index" do
    it "renders" do
      expect(current_organization.appointment_functionality_enabled?).to be_truthy
      get base_url
      expect(flash).to be_blank
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "create" do
    let(:appointment_params) { {name: "Sarah h.", email: "something@stuff.com", reason: "Service", location_id: location.id, status: "on_deck"} }
    it "creates and assigns the appointment" do
      current_organization.reload
      location.reload
      expect(current_organization.appointments.count).to eq 0
      expect(location.appointments.count).to eq 0
      expect(appointment_configuration.reasons.include?(appointment_params[:reason])).to be_truthy
      Sidekiq::Worker.clear_all
      expect {
        post base_url, params: {organization_id: current_organization.to_param, appointment: appointment_params}
      }.to change(Appointment, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 1
      location.reload
      current_organization.reload
      expect(location.appointments.count).to eq 1
      new_appointment = location.appointments.last

      expect(response).to redirect_to(organization_appointments_path(organization_id: current_organization.to_param))
      expect(flash[:success]).to be_present

      expect(new_appointment.status).to eq "on_deck"
      expect(new_appointment.name).to eq appointment_params[:name]
      expect(new_appointment.email).to eq appointment_params[:email]
      expect(new_appointment.reason).to eq appointment_params[:reason]
      expect(new_appointment.location_id).to eq location.id
      expect(new_appointment.organization_id).to eq current_organization.id
      expect(new_appointment.user_id).to eq current_user.id
      expect(new_appointment.creator_kind).to eq "organization_member"
      expect(new_appointment.appointment_updates.count).to eq 0

      # It also can create an appointment without an email
      # squeezing in this test here because idgaf
      expect {
        post base_url, params: {
          organization_id: current_organization.to_param,
          appointment: appointment_params.merge(email: " ", status: "")
        }
      }.to change(Appointment, :count).by 1
      expect(response).to redirect_to(organization_appointments_path(organization_id: current_organization.to_param))
      expect(flash[:success]).to be_present

      new_appointment2 = Appointment.last
      expect(new_appointment2.status).to eq "waiting"
    end
  end

  describe "update" do
    it "updates with a new status" do
      expect(appointment.appointment_updates.count).to eq 0
      expect {
        put "#{base_url}/#{appointment.id}", params: {status: "being_helped"}
      }.to change(AppointmentUpdate, :count).by 1
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(organization_appointments_path(organization_id: current_organization.to_param))

      appointment.reload
      expect(appointment.status).to eq "being_helped"

      appointment_update = appointment.appointment_updates.last
      expect(appointment_update.status).to eq "being_helped"
      expect(appointment_update.user_id).to eq current_user.id
      expect(appointment_update.creator_kind).to eq "organization_member"
    end
    context "update multiple" do
      let!(:appointment2) { FactoryBot.create(:appointment, status: "on_deck", organization: current_organization, location: location) }
      it "updates multiple appointments" do
        expect {
          put "#{base_url}/multi_update", params: {
            status: "being_helped",
            organization: current_organization.to_param,
            ids: {
              appointment.id.to_s => appointment.id.to_s,
              appointment2.id.to_s => appointment2.id.to_s
            }
          }
        }.to change(AppointmentUpdate, :count).by 2
        expect(response).to redirect_to organization_appointments_path(organization_id: current_organization.to_param)
        expect(flash[:success]).to be_present
        appointment.reload
        appointment2.reload

        expect(appointment.status).to eq "being_helped"
        expect(appointment2.status).to eq "being_helped"

        expect(appointment.appointment_updates.count).to eq 1
        expect(appointment.appointment_updates.last.organization_member?).to be_truthy
        expect(appointment2.appointment_updates.last.user_id).to eq current_user.id
        # updating with no ids doesn't break
        expect {
          put "#{base_url}/multi_update", params: {
            status: "being_helped",
            organization: current_organization.to_param
          }
        }.to_not change(AppointmentUpdate, :count)
        expect(response).to redirect_to organization_appointments_path(organization_id: current_organization.to_param)
        expect(flash).to be_present
      end
    end
  end
end
