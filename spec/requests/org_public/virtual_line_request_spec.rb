require "rails_helper"

RSpec.describe OrgPublic::VirtualLineController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/virtual_line" }
  let(:current_organization) { FactoryBot.create(:organization) }

  it "redirects" do
    expect do
      get "/some-known-organization/virtual_line"
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

  context "with appointment configuration, virtual line off" do
    let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, virtual_line_on: false) }
    let(:current_location) { appointment_configuration.location }
    let(:current_organization) { current_location.organization }

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

  context "virtual line on" do
    let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, virtual_line_on: true) }
    let(:current_location) { appointment_configuration.location }
    let(:current_organization) { current_location.organization }

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
          # But it doesn't store the ticket token in session, because it isn't claimed
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(flash).to be_blank
          expect(assigns(:appointment)&.id).to be_blank
          expect(assigns(:ticket)&.id).to eq ticket.id
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
            ticket.reload
            expect(ticket.claimed?).to be_truthy
            # Ticket is stored in session, so, it works without any token after initial load
            # get base_url
            # expect(response.status).to eq(200)
            # expect(response).to render_template :index
            # expect(flash).to be_blank
            # expect(assigns(:ticket)&.id).to eq ticket.id
            # expect(assigns(:appointment)&.id).to eq appointment.id
          end
          describe "appointment is resolved" do
            it "removes it from the session" do
              get "#{base_url}?ticket_token=#{ticket.link_token}"
              expect(response.status).to eq(200)
              expect(response).to render_template :index
              expect(flash).to be_blank
              expect(assigns(:appointment)&.id).to eq appointment.id
              expect(assigns(:ticket)&.id).to eq ticket.id
              appointment.record_status_update(new_status: "being_helped")
              appointment.reload
              expect(appointment.no_longer_in_line?).to be_truthy
              # get "#{base_url}?ticket_token=#{ticket.link_token}"
              # expect(response.status).to eq(200)
              # expect(response).to render_template :index
              # expect(flash[:info]).to match(/line/i)
              # expect(assigns(:ticket)&.id).to be_blank
              # expect(assigns(:appointment)&.id).to be_blank
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
  end
end
