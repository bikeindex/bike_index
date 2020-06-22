require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL other TESTS IN  Request spec !
#
RSpec.describe OrgPublic::CustomerAppointmentsController, type: :controller do
  let(:appointment) { FactoryBot.create(:appointment_with_virtual_line_on) }
  let(:current_organization) { appointment.organization }
  let(:location) { appointment.location }

  describe "assign_current_appointment" do
    it "redirects, puts the appointment_token in session" do
      location.reload
      expect(location.virtual_line_on?).to be_truthy
      session[:appointment_token] = nil
      post :set_current_appointment, params: { organization_id: current_organization.to_param, id: appointment.link_token }
      expect(assigns(:current_appointment)).to eq appointment
      expect(response).to redirect_to(organization_customer_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
      expect(flash).to be_blank
      expect(session[:appointment_token]).to eq appointment.link_token
    end
    context "appointment_token in session" do
      it "falls back to the session appointment, flash errors" do
        session[:appointment_token] = appointment.link_token
        post :set_current_appointment, params: { organization_id: current_organization.to_param, id: "fasdfffdsf" }
        expect(flash[:error]).to be_present
        session[:appointment_token] = appointment.link_token
        expect(assigns(:current_appointment)).to eq appointment
        expect(response).to redirect_to(organization_customer_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
      end
      context "different appointment_token in session" do
        let!(:appointment2) { FactoryBot.create(:appointment, organization: current_organization, location_id: 212221) }
        it "sets the new appointment" do
          session[:appointment_token] = appointment2.link_token
          expect(appointment2.location_id).to_not eq appointment.location_id
          post :set_current_appointment, params: {
            organization_id: current_organization.to_param,
            location_id: appointment2.location_id,
            id: appointment.link_token
          }
          expect(session[:appointment_token]).to eq appointment.link_token
          expect(assigns(:current_appointment)).to eq appointment
          expect(assigns(:current_location)).to eq appointment.location
          expect(response).to redirect_to(organization_customer_line_path(organization_id: current_organization.to_param, location_id: location.to_param))
          expect(flash).to be_blank
        end
      end
    end
  end

  describe "create" do
    # let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
    # let(:current_organization) { location.organization }
    # let(:appointment_params) do
    #   {

    #   }
    # end

    # it "assigns the appointment to session" do
    #   current_organization.reload
    #   location.reload
    #   expect(current_organization.appointments.count).to eq 0
    #   expect(location.appointments.count).to eq 0
    #   pp appointment_params
    #   expect do
    #     post :create, params: { organization_id: current_organization.to_param, appointment: appointment_params }
    #   end.to change(Appointment, :count).by 1

    #   expect(assigns(:current_appointment)).to eq appointment
    #   expect(session[:appointment_token]).to eq appointment.link_token
    #   expect(response).to redirect_to(organization_customer_line_path(organization_id: current_organization.to_param))
    #   expect(flash[:success]).to be_present
    # end
  end
end
