require "rails_helper"

RSpec.describe Ticket, type: :model do
  let(:location) { FactoryBot.create(:location) }
  let!(:organization) { location.organization }

  describe "create_tickets" do
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

  describe "claim!" do
    let(:ticket) { Ticket.create_tickets(1, location: location).first }

    it "sets the claimed_at and sets the ticket_number on the appointment" do
      ticket.reload
      expect(ticket.number).to eq 1
      expect(ticket.claimed?).to be_falsey
      expect(ticket.appointment).to be_blank
      expect do
        expect(ticket.claim(email: "stuff@example.coM")).to be_truthy
      end.to change(Appointment, :count).by 1
      expect(ticket.claimed?).to be_truthy
      expect(ticket.claimed_at).to be_within(1).of Time.current
      appointment = ticket.appointment
      expect(appointment.appointment_at).to be_within(1).of Time.current
      expect(appointment.email).to eq "stuff@example.com"
      expect(appointment.status).to eq "waiting"
      expect(appointment.creator_kind).to eq "ticket_claim"
      expect(appointment.location).to eq location
      expect(appointment.ticket_number).to eq ticket.number
      expect(appointment.position_in_line).to eq 100
      # But - it can claim by the same user again
      expect do
        expect(ticket.claim(email: " stuff@example.com ")).to be_truthy
        new_user = FactoryBot.create(:user_confirmed, email: "stuff@example.com")
        expect(ticket.claim(user_id: new_user.id)).to be_truthy
      end.to_not change(Appointment, :count)
      ticket.reload
      expect(ticket.appointment).to eq appointment
    end
    context "appointment already created" do
      let!(:appointment) { ticket.create_new_appointment(user_id: 12) }
      it "adds an error and returns false" do
        # TODO: have this return false and include an error
      end
    end
    context "user already has too many for the time period" do
      let!(:appointment) { ticket.create_new_appointment(user_id: 12) }
      it "adds an error and returns false" do
        # TODO: have this return false and include an error
      end
    end
  end
end
