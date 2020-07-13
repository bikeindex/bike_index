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
    let(:user) { FactoryBot.create(:user_confirmed, email: "stuff@example.com") }

    it "sets the claimed_at and sets the ticket_number on the appointment" do
      ticket.reload
      expect(ticket.number).to eq 1
      expect(ticket.claimed?).to be_falsey
      expect(ticket.appointment).to be_blank
      expect do
        expect(ticket.claim(email: "stuff@example.coM", creation_ip: "108.000.215.126")).to be_truthy
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
      expect(appointment.creation_ip.to_s).to eq "108.000.215.126"
      # But - it can claim by the same user again
      expect do
        expect(User.count).to eq 0
        expect(ticket.claim(email: " stuff@example.com ")).to be_truthy
        expect(ticket.claim(user_id: user.id)).to be_truthy
      end.to_not change(Appointment, :count)
      ticket.reload
      expect(ticket.appointment).to eq appointment
    end
    context "appointment already created" do
      let!(:appointment) do
        ticket.claim(user_id: 12)
        ticket.appointment
      end
      it "adds an error and returns false, even though not claimed" do
        ticket.reload
        expect(ticket.number).to eq 1
        expect(ticket.claimed?).to be_truthy
        expect(ticket.appointment).to eq appointment
        expect(ticket.errors.full_messages.count).to eq 0
        expect do
          expect(ticket.claim(email: "stuff@example.coM")).to be_falsey
        end.to_not change(Appointment, :count)
        expect(ticket.errors.full_messages.count).to eq 1
        expect(ticket.errors.full_messages.to_s).to match(/claimed/)
      end
    end
    context "user already has too many for the time period" do
      let!(:ticket1) { FactoryBot.create(:ticket_claimed, location: location, user: user) }
      let!(:ticket2) { FactoryBot.create(:ticket_claimed, user: user) }
      it "adds an error and returns false when past too_many_recent_claimed_tickets?" do
        expect(ticket1.claimed?).to be_truthy
        expect(ticket2.claimed?).to be_truthy
        expect(ticket2.appointment.user_id).to eq user.id
        # Ticket2 is for a different organization and location
        expect(ticket2.location_id).to_not eq ticket.organization_id
        expect(ticket2.organization_id).to_not eq ticket1.organization_id

        ticket.reload
        expect(ticket.claimed?).to be_falsey
        expect(ticket.appointment).to be_blank
        expect(Ticket.too_many_recent_claimed_tickets?(email: user.email)).to be_truthy
        expect do
          expect(ticket.claim(email: "stuff@example.coM")).to be_falsey
        end.to_not change(Appointment, :count)
        expect(ticket.errors.full_messages.count).to eq 1
        expect(ticket.errors.full_messages.to_s).to match(/many/)
        expect(ticket.claimed?).to be_falsey
        expect(ticket.appointment).to be_blank
        # If one of the tickets is abandoned, claiming another ticket is still blocked
        ticket2.appointment.update(status: "abandoned")
        expect(Ticket.too_many_recent_claimed_tickets?(email: user.email)).to be_truthy

        # If a ticket is being_helped though, they no longer have too many appointments in line
        ticket1.appointment.update(status: "being_helped")
        expect(Ticket.too_many_recent_claimed_tickets?(email: user.email)).to be_falsey
        expect do
          ticket.valid? # clears the errors
          expect(ticket.claim(email: "stuff@example.coM")).to be_truthy
        end.to change(Appointment, :count).by 1
      end
    end
  end
end
