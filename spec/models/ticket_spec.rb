require "rails_helper"

RSpec.describe Ticket, type: :model do
  describe "create_tickets" do
    let(:location) { FactoryBot.create(:location) }
    let!(:organization) { location.organization }
    it "creates tickets" do
      expect do
        Ticket.create_tickets(3, initial_number: 200, location: location)
      end.to change(Ticket, :count).by 3
      expect(Ticket.distinct.pluck(:organization_id)).to eq([organization.id])
      expect(Ticket.distinct.pluck(:location_id)).to eq([location.id])
      ticket0 = Ticket.number_ordered.first
      ticket1 = Ticket.number_ordered.second
      ticket2 = Ticket.number_ordered.third
      expect(ticket0.number).to eq 200
      expect(ticket1.number).to eq 201
      expect(ticket2.number).to eq 202
      expect(ticket0.status).to eq "unused"

      ticket3 = Ticket.create_tickets(1, location: location, organization: organization).first
      expect(ticket3.number).to eq 203
      # It doesn't break if passed the previous number
      ticket4 = Ticket.create_tickets(1, initial_number: 203, location: location).first
      expect(ticket4.number).to eq 204
    end
  end
end
