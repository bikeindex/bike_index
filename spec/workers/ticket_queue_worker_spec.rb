require "rails_helper"

RSpec.describe TicketQueueWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:location) { FactoryBot.create(:location, :with_virtual_line_on, customers_on_deck_count: 2) }
    let(:appointment_configuration) { location.appointment_configuration }
    let(:organization) { location.organization }
    before do
      expect(appointment_configuration.customers_on_deck_count).to eq 2
      stub_const("TicketQueueWorker::DEFAULT_TICKETS_IN_LINE_COUNT", 5)
    end

    context "no tickets" do
      it "creates default number of tickets in line" do
        expect do
          instance.perform(location.id, 1011)
        end.to change(Ticket, :count).by 5
        location.reload
        expect(location.tickets.count).to eq 5
        expect(location.tickets.line_ordered.first.number).to eq 1011
      end
      context "not passed ticket_id or ticket number" do
        it "does nothing" do
          expect do
            instance.perform(location.id)
          end.to change(Ticket, :count).by 0
        end
      end
    end

    context "3 existing tickets" do
      let(:tickets) { Ticket.create_tickets(3, initial_number: 101, organization: organization) } # Tests that it pulls the default location
      let!(:ticket1) { tickets.line_ordered.first }
      it "creates just 2 tickets and bumps the remaining ones into line" do
        expect(ticket1.number).to eq 101
        expect(ticket1.status).to eq "pending"
        expect do
          instance.perform(location.id, nil, ticket_number: 102)
        end.to change(Ticket, :count).by 0
      end
      context "not passed ticket number" do
        it "creates next tickets" do
          expect(location.tickets.pending.count).to eq 3
          expect do
            instance.perform(location.id)
          end.to change(Ticket, :count).by 2
          location.reload
          expect(location.tickets.pending.count).to eq 0
          expect(location.tickets.in_line.pluck(:number)).to eq([102, 103, 104, 105, 106])
          expect(location.tickets.paging_or_on_deck.pluck(:number)).to eq([102, 103])
        end
      end
      context "ticket number passed is being_helped" do
        let(:ticket2) { tickets.line_ordered[1] }
        let!(:appointment) { ticket2.claim(email: "stuff@example.com") }
        it "behaves as if the next number was passed" do
          ticket2.reload
          expect(ticket2.number).to eq 101
          expect(ticket2.status).to eq "waiting"
          expect(appointment.status).to eq "waiting"
          expect do
            appointment.record_status_update(new_status: "being_helped")
          end.to change(described_class.jobs, :count).by 1
          ticket2.reload
          expect(ticket2.status).to eq "being_helped"
          expect do
            instance.perform(location.id, ticket2.number)
          end.to change(Ticket, :count).by 4
          ticket1.reload
          expect(ticket1.status).to eq "removed"
          ticket2.reload
          expect(ticket2.status).to eq "being_helped"
          expect(location.tickets.in_line.pluck(:number)).to eq([103, 104, 105, 106, 107])
          expect(location.tickets.paging_or_on_deck.pluck(:number)).to eq([103, 104])
        end
      end
    end
  end
end
