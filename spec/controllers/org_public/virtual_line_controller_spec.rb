require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL other TESTS IN  Request spec !
#
RSpec.describe OrgPublic::VirtualLineController, type: :controller do
  let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, virtual_line_on: true) }
  let(:current_location) { appointment_configuration.location }
  let(:current_organization) { current_location.organization }

  describe "index" do
    let(:ticket) { FactoryBot.create(:ticket, location: current_location) }
    it "renders, doesn't set the ticket_token" do
      current_location.reload
      expect(current_location.virtual_line_on?).to be_truthy
      session[:ticket_token] = nil
      get :index, params: { organization_id: current_organization.to_param, ticket_token: ticket.link_token }
      expect(assigns(:ticket)&.id).to eq ticket.id
      expect(flash).to be_blank
      expect(session[:ticket_token]).to be_blank
    end
    context "ticket_token in session" do
      it "uses the ticket_token from session" do
        session[:ticket_token] = ticket.link_token
        get :index, params: { organization_id: current_organization.to_param, location_id: current_location.to_param }
        expect(flash).to be_blank
        expect(assigns(:ticket)&.id).to eq ticket.id
        expect(session[:ticket_token]).to eq ticket.link_token
      end
    end
    context "ticket resolved" do
      let!(:ticket) { FactoryBot.create(:ticket, location: current_location, status: "resolved") }
      it "removes it from the session" do
        session[:ticket_token] = ticket_older.link_token
        get :index, params: { organization_id: current_organization.to_param }
        expect(assigns(:ticket)&.id).to be_blank
        expect(flash).to match(/line/)
        expect(session[:ticket_token]).to be_blank
      end
    end
    context "claimed ticket" do
      let!(:ticket) { FactoryBot.create(:ticket_claimed, location: current_location) }
      it "puts ticket_token in session" do
        session[:ticket_token] = nil
        get :index, params: { organization_id: current_organization.to_param, ticket_token: ticket.link_token }
        expect(assigns(:ticket)&.id).to eq ticket.id
        expect(flash).to be_blank
        expect(session[:ticket_token]).to eq ticket.link_token
      end
      context "different link_token in session" do
        let!(:ticket_older) { FactoryBot.create(:ticket, organization: current_organization, location_id: 212221) }
        it "sets the new ticket" do
          session[:ticket_token] = ticket.link_token
          expect(ticket_older.location_id).to_not eq current_location.id
          get :index, params: {
                               organization_id: current_organization.to_param,
                               ticket_token: ticket.link_token,
                             }
          expect(flash).to be_blank
          expect(assigns(:ticket)&.id).to eq ticket.id
          expect(session[:ticket_token]).to eq ticket.link_token
          expect(assigns(:current_location)).to eq ticket.location
        end
      end
    end
  end
end
