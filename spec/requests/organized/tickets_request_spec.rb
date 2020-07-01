require "rails_helper"

RSpec.describe Organized::TicketsController, type: :request do
  include_context :request_spec_logged_in_as_organization_member
  let(:base_url) { "/o/#{current_organization.to_param}/tickets" }
  let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
  let(:current_organization) { location.organization }
  let(:appointment_configuration) { location.appointment_configuration }

  describe "print" do
    let!(:tickets) { Ticket.create_tickets(3, initial_number: 20, location: location) }
    it "renders" do
      expect(location.tickets.count).to eq 3
      get "#{base_url}/print?location_id=#{location.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:print)
      expect(assigns(:tickets).pluck(:id)).to match_array(tickets.map(&:id))
    end
  end
end
