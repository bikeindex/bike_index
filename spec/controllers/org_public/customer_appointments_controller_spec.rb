require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL other TESTS IN  Request spec !
#
RSpec.describe OrganizationPublic::CustomerAppointmentsController, type: :controller do
  let(:appointment) { FactoryBot.create(:appointment, location: location, organization: current_organization) }
  let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
  let(:current_organization) { location.organization }
  let(:appointment_configuration) { location.appointment_configuration }

  describe "set_current" do
    it "redirects, puts the appointment_token in session" do
      location.reload
      expect(location.virtual_line_on?).to be_truthy
      session[:appointment_token] = nil
      post :set_current, params: {organization_id: current_organization.to_param, appointment_token: appointment.link_token}
      expect(assigns(:current_appointment)).to eq appointment
      expect(response).to redirect_to(organization_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
      expect(flash).to be_blank
      expect(session[:appointment_token]).to eq appointment.link_token
    end
    context "appointment_token in session" do
      it "falls back to the session appointment, flash errors, doesn't overwrite existing appointment" do
        session[:appointment_token] = appointment.link_token
        post :set_current, params: {organization_id: current_organization.to_param, appointment_token: "fasdfffdsf", location_id: location.to_param}
        expect(flash[:error]).to be_present
        expect(session[:appointment_token]).to eq appointment.link_token
        expect(assigns(:current_appointment)).to be_blank
        expect(response).to redirect_to(organization_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
      end
      context "different appointment_token in session" do
        let!(:appointment2) { FactoryBot.create(:appointment, organization: current_organization, location_id: 212221) }
        it "sets the new appointment" do
          session[:appointment_token] = appointment2.link_token
          expect(appointment2.location_id).to_not eq appointment.location_id
          post :set_current, params: {
            organization_id: current_organization.to_param,
            location_id: appointment2.location_id,
            appointment_token: appointment.link_token
          }
          expect(session[:appointment_token]).to eq appointment.link_token
          expect(assigns(:current_appointment)).to eq appointment
          expect(assigns(:current_location)).to eq appointment.location
          expect(response).to redirect_to(organization_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
          expect(flash).to be_blank
        end
      end
    end
  end

  describe "create" do
    let(:appointment_params) { {name: "Sarah h.", email: "something@stuff.com", reason: "Service", location_id: location.id} }
    it "assigns the appointment to session" do
      current_organization.reload
      location.reload
      expect(current_organization.appointments.count).to eq 0
      expect(location.appointments.count).to eq 0
      Sidekiq::Worker.clear_all
      expect {
        post :create, params: {
          organization_id: current_organization.to_param,
          location_id: location.to_param,
          appointment: appointment_params
        }
      }.to change(Appointment, :count).by 1
      location.reload
      current_organization.reload
      expect(location.appointments.count).to eq 1
      new_appointment = location.appointments.last
      expect(new_appointment.notifications.count).to eq 0

      expect(assigns(:current_appointment)).to eq new_appointment
      expect(session[:appointment_token]).to eq new_appointment.link_token
      expect(response).to redirect_to(organization_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
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
