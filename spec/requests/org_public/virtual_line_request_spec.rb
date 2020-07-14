require "rails_helper"

RSpec.describe OrgPublic::VirtualLineController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/virtual_line" }
  let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, virtual_line_on: true) }
  let(:current_location) { appointment_configuration.location }
  let(:current_organization) { current_location.organization }
  let(:virtual_line_root_url) { organization_virtual_line_index_path(organization_id: current_organization.to_param, location_id: current_location.to_param) }

  context "current_organization not found" do
    it "redirects" do
      expect do
        get "/some-known-organization/virtual_line"
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "virtual_line not enabled" do
    let(:current_location) { FactoryBot.create(:location) }
    it "redirects" do
      expect(current_organization.appointment_functionality_enabled?).to be_falsey
      get base_url
      expect(flash[:error]).to be_present
      expect(response).to redirect_to root_url
    end
  end

  context "with appointment configuration, virtual line off" do
    let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, virtual_line_on: false) }
    it "redirects" do
      expect(current_organization.appointment_functionality_enabled?).to be_truthy
      expect(current_location.virtual_line_on?).to be_falsey
      get base_url
      expect(flash[:error]).to be_present
      expect(response).to redirect_to root_url
    end

    context "logged_in_as_organization_member" do
      include_context :request_spec_logged_in_as_organization_member
      let(:current_organization) { current_location.organization }
      describe "index" do
        it "renders" do
          expect(current_location.virtual_line_on?).to be_falsey
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(assigns(:current_location)).to eq current_location
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

  describe "index" do
    it "renders" do
      expect(current_location.virtual_line_on?).to be_truthy
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template :index
      expect(assigns(:current_location)).to eq current_location
      expect(assigns(:current_organization)).to eq current_organization
      expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
      expect(assigns(:appointment)&.id).to be_blank # Because it's a new appointment
      expect(assigns(:ticket)&.id).to be_blank

      # But - if we remove the organization access, it fails
      appointment_configuration.update(virtual_line_on: false)
      current_location.reload
      expect(current_location.virtual_line_on?).to be_falsey
      get base_url
      expect(flash[:error]).to be_present
      expect(response).to redirect_to root_url
    end
    context "multiple location" do
      let!(:location_off) { FactoryBot.create(:location, organization: current_organization) }
      it "flash errors unless the location targeted is on" do
        expect(current_organization.appointment_functionality_enabled?).to be_truthy
        expect(current_location.virtual_line_on?).to be_truthy
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
        get "#{base_url}?location_id=#{current_location.to_param}"
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_location)).to eq current_location
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
        expect(assigns(:ticket)).to be_blank
      end
    end

    context "with ticket" do
      let!(:ticket) { FactoryBot.create(:ticket, location: current_location) }
      it "renders, doesn't mark ticket claimed" do
        expect(ticket.claimed?).to be_falsey
        get "#{base_url}?ticket_token=#{ticket.link_token}"
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_location)).to eq current_location
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
        expect(assigns(:appointment)&.id).to be_blank # Because it's a new appointment
        expect(assigns(:ticket)&.id).to eq ticket.id
        ticket.reload
        expect(ticket.claimed?).to be_falsey
      end
      context "ticket claimed" do
        let(:ticket) { FactoryBot.create(:ticket_claimed, location: current_location) }
        let!(:appointment) { ticket.appointment }
        it "renders with ticket" do
          expect(appointment.in_line?).to be_truthy
          expect(appointment.ticket).to eq ticket
          expect(ticket.claimed?).to be_truthy
          get "#{base_url}?ticket_token=#{ticket.link_token}"
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(flash).to be_blank
          expect(assigns(:current_location)).to eq current_location
          expect(assigns(:current_organization)).to eq current_organization
          expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
          expect(assigns(:appointment)&.id).to eq appointment.id
          expect(assigns(:ticket)&.id).to eq ticket.id
        end
        describe "appointment is resolved" do
          it "removes it from the session" do
            appointment.record_status_update(new_status: "being_helped")
            appointment.reload
            expect(appointment.no_longer_in_line?).to be_truthy
            get "#{base_url}?ticket_token=#{ticket.link_token}"
            expect(response.status).to eq(200)
            expect(response).to render_template :index
            expect(flash[:info]).to match(/line/i)
            expect(assigns(:ticket)&.id).to be_blank
            expect(assigns(:appointment)&.id).to be_blank
          end
        end
      end
      context "ticket resolved" do
        let!(:ticket) { FactoryBot.create(:ticket, location: current_location, status: "resolved") }
        it "renders without ticket" do
          get "#{base_url}?ticket_token=#{ticket.link_token}"
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(flash[:info]).to match(/line/i)
          expect(assigns(:ticket)&.id).to be_blank
        end
      end
    end
  end

  describe "create" do
    let!(:ticket) { FactoryBot.create(:ticket, location: current_location) }
    it "sends back with the ticket assigned" do
      expect(ticket.claimed?).to be_falsey
      expect do
        post base_url, params: {
                         organization_id: current_organization.to_param,
                         ticket_number: ticket.number,
                       }
      end.to_not change(Notification, :count)
      expect(flash[:success]).to be_present
      expect(assigns(:ticket)&.id).to eq ticket.id
      ticket.reload
      expect(ticket.claimed?).to be_falsey
    end
    context "resolved ticket" do
      let!(:ticket) { FactoryBot.create(:ticket, location: current_location, status: "resolved") }
      it "redirects with flash, no ticket" do
        expect do
          post base_url, params: {
                           organization_id: current_organization.to_param,
                           ticket_number: "#{ticket.number}",
                         }
        end.to_not change(Notification, :count)
        expect(flash[:info]).to match(/resolved/)
        expect(response).to redirect_to virtual_line_root_url
        expect(assigns(:ticket)&.id).to be_blank
      end
    end
    context "unknown ticket" do
      it "behaves the same as resolved" do
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect do
          post base_url, params: {
                           organization_id: current_organization.to_param,
                           ticket_number: 2222222,
                         }
        end.to_not change(Notification, :count)
        expect(flash[:error]).to be_present
        expect(response).to redirect_to virtual_line_root_url
        expect(assigns(:ticket)&.id).to be_blank
      end
    end
    context "claimed ticket" do
      let!(:ticket) { FactoryBot.create(:ticket_claimed, location: current_location) }
      it "redirects with flash, no ticket" do
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect do
          post base_url, params: {
                           organization_id: current_organization.to_param,
                           ticket_number: ticket.number,
                         }
        end.to change(Notification, :count).by 1
        expect(flash[:info]).to be_present
        expect(response).to redirect_to virtual_line_root_url
        expect(assigns(:ticket)&.id).to be_blank
        expect(SendNotificationWorker.jobs.count).to eq 1
        SendNotificationWorker.drain
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(ActionMailer::Base.deliveries.last.subject).to eq "View your place in the #{current_organization.short_name} line"
      end
      context "appointment is resolved" do
        let(:appointment) { ticket.appointment }
        it "behaves the same way as resolved" do
          appointment.record_status_update(new_status: "being_helped")
          appointment.reload
          expect(appointment.no_longer_in_line?).to be_truthy
          expect do
            post base_url, params: {
                             organization_id: current_organization.to_param,
                             ticket_number: "#{ticket.number}",
                           }
          end.to_not change(Notification, :count)
          expect(flash[:info]).to match(/helped already/)
          expect(response).to redirect_to virtual_line_root_url
          expect(assigns(:ticket)&.id).to be_blank
        end
      end
    end
  end

  describe "update" do
    let!(:ticket) { FactoryBot.create(:ticket, location: current_location) }
    it "creates an appointment" do
      expect do
        put "#{base_url}/#{ticket.to_param}", params: {
                                                organization_id: current_organization.to_param,
                                                ticket_token: ticket.link_token,
                                                appointment: {
                                                  email: "something@stuff.COM",
                                                  reason: "Service",
                                                },
                                              }
        pp flash
      end.to change(Appointment, :count).by 1
      expect(flash[:success]).to be_present
      expect(response).to redirect_to virtual_line_root_url
      expect(assigns(:ticket)).to eq ticket
      ticket.reload
      expect(ticket.claimed?).to be_truthy
      appointment = ticket.appointment
      expect(appointment.email).to eq "something@stuff.com"
      expect(appointment.reason).to eq "Service"
      expect(appointment.status).to eq "waiting"
    end
    context "unknown ticket_token" do
      it "flash errors" do

      end
    end
    context "user is not permitted to create another appointment" do
      it "flash errors" do

      end
    end
    context "appointment exists" do
      it "update to status abandoned" do
        # It does not permit marking them abandoned
      end
      context "user signed in" do
        it "permits marking the ticket abandoned"
      end
    end
  end
end
