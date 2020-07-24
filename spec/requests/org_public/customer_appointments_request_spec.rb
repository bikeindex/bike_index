require "rails_helper"

RSpec.describe OrgPublic::CustomerAppointmentsController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/customer_appointments" }
  let(:appointment) { FactoryBot.create(:appointment, status: status, location: location, organization: current_organization) }
  let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
  let(:current_organization) { location.organization }
  let(:appointment_configuration) { location.appointment_configuration }
  let(:status) { "waiting" }

  describe "show" do
    it "redirects if passed token" do
      expect(location.virtual_line_on?).to be_truthy
      expect(appointment.link_token).to be_present
      get "#{base_url}/#{appointment.id}"
      expect(response).to redirect_to organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param)
      expect(flash[:error]).to be_present

      get "#{base_url}/#{appointment.link_token}"
      expect(assigns(:current_location)).to eq location
      expect(assigns(:current_organization)).to eq current_organization
      expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
      expect(flash).to be_blank
      expect(response).to redirect_to organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param)
    end
  end

  describe "set_current" do
    it "redirects" do
      post "#{base_url}/set_current", params: {appointment_token: appointment.link_token}
      expect(assigns(:current_location)).to eq location
      expect(assigns(:current_organization)).to eq current_organization
      expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
      expect(flash).to be_blank
      expect(response).to redirect_to organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param)
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

      expect(assigns(:current_appointment)).to eq new_appointment
      expect(response).to redirect_to(organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param))
      expect(flash[:success]).to be_present

      expect(new_appointment.status).to eq "waiting"
      expect(new_appointment.name).to eq appointment_params[:name]
      expect(new_appointment.email).to eq appointment_params[:email]
      expect(new_appointment.reason).to eq appointment_params[:reason]
      expect(new_appointment.location_id).to eq location.id
      expect(new_appointment.organization_id).to eq current_organization.id
      expect(new_appointment.creator_kind).to eq "no_user"
      expect(new_appointment.user_id).to be_blank
      expect(new_appointment.appointment_updates.count).to eq 0
    end
    context "no email" do
      it "denies" do
        Sidekiq::Worker.clear_all
        expect {
          post base_url, params: {
            organization_id: current_organization.to_param,
            appointment: appointment_params.merge(email: " ")
          }
        }.to_not change(Appointment, :count)
        expect(flash[:error]).to be_present
      end
    end
    context "current user" do
      include_context :request_spec_logged_in_as_user
      it "creates" do
        current_organization.reload
        expect {
          post base_url, params: {organization_id: current_organization.to_param, appointment: appointment_params}
        }.to change(Appointment, :count).by 1
        new_appointment = location.appointments.last

        expect(assigns(:current_appointment)).to eq new_appointment
        expect(response).to redirect_to(organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param))
        expect(flash[:success]).to be_present

        expect(new_appointment.status).to eq "waiting"
        expect(new_appointment.name).to eq appointment_params[:name]
        expect(new_appointment.email).to eq appointment_params[:email]
        expect(new_appointment.reason).to eq appointment_params[:reason]
        expect(new_appointment.location_id).to eq location.id
        expect(new_appointment.organization_id).to eq current_organization.id
        expect(new_appointment.creator_kind).to eq "signed_in_user"
        expect(new_appointment.user).to eq current_user
        expect(new_appointment.appointment_updates.count).to eq 0
      end
    end
  end

  describe "update" do
    let(:appointment_params) do
      {
        name: "Sarah h.",
        email: "something@stuff.com",
        reason: "Service",
        status: update_status,
        description: "something cool, etc"
      }
    end
    let(:update_status) { "being_helped" }
    it "updates things" do
      expect(appointment.appointment_updates.count).to eq 0
      Sidekiq::Worker.clear_all
      put "#{base_url}/#{appointment.link_token}", params: {appointment: appointment_params}
      expect(response).to redirect_to(organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param))
      expect(flash[:success]).to be_present
      appointment.reload

      expect(assigns(:current_appointment)).to eq appointment
      expect_attrs_to_match_hash(appointment, appointment_params)

      expect(appointment.appointment_updates.count).to eq 1
      appointment_update = appointment.appointment_updates.last
      expect(appointment_update.status).to eq "being_helped"
      expect(appointment_update.no_user?).to be_truthy
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 1
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([appointment.location_id])
    end
    context "unpermitted updates" do
      it "ignores illegal things" do
        put "#{base_url}/#{appointment.link_token}", params: {
          appointment: appointment_params.merge(status: "on_deck",
                                                location_id: 2121212,
                                                user_id: 22222,
                                                organization_id: 16262)
        }
        expect(response).to redirect_to(organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param))
        expect(flash[:success]).to be_present
        appointment.reload

        expect(assigns(:current_appointment)).to eq appointment
        expect_attrs_to_match_hash(appointment, appointment_params.except(:status))
        expect(appointment.location_id).to eq location.id
        expect(appointment.user_id).to eq appointment.user_id
        expect(appointment.organization_id).to eq current_organization.id
        expect(appointment.appointment_updates.count).to eq 0
      end
    end
    context "status: on_deck" do
      let(:status) { "on_deck" }
      it "stays on_deck, updates if updating" do
        put "#{base_url}/#{appointment.link_token}", params: {appointment: appointment_params.merge(status: "on_deck")}
        expect(response).to redirect_to(organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param))
        expect(flash[:success]).to be_present
        appointment.reload

        expect(assigns(:current_appointment)).to eq appointment
        expect_attrs_to_match_hash(appointment, appointment_params.except(:status))
        expect(appointment.status).to eq "on_deck" # Ensuring status remains, even though we block assigning to on_deck

        put "#{base_url}/#{appointment.link_token}", params: {appointment: appointment_params}
        appointment.reload
        expect(assigns(:current_appointment)).to eq appointment
        expect_attrs_to_match_hash(appointment, appointment_params)
      end
    end
    context "status: being_helped" do
      let(:status) { "being_helped" }
      let(:update_status) { "abandoned" }
      it "does not permit status update" do
        expect(appointment.appointment_updates.count).to eq 0
        put "#{base_url}/#{appointment.link_token}", params: {appointment: appointment_params}
        expect(response).to redirect_to(organization_walkrightup_path(organization_id: current_organization.to_param, location_id: location.to_param))
        expect(flash[:success]).to be_present
        appointment.reload

        expect(assigns(:current_appointment)).to eq appointment
        expect_attrs_to_match_hash(appointment, appointment_params.except(:status))
        expect(appointment.status).to eq "being_helped"
      end
    end
    context "status: removed" do
      let(:status) { "removed" }
      let(:update_status) { "waiting" }
      it "does not permit any updates" do
        put "#{base_url}/#{appointment.link_token}", params: {appointment: appointment_params}
        expect(flash[:error]).to be_present
        appointment.reload

        appointment_params.each do |k, v|
          pp k, v if appointment.send(k).to_s == v
          expect(appointment.send(k)).to_not eq v
        end
        expect(appointment.status).to eq "removed"
        expect(appointment.appointment_updates.count).to eq 0
      end
    end
  end
end
