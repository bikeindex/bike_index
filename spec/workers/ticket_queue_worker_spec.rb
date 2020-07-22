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
    end
    # it "marks the next tickets as in line" do
    #   Ticket.create_tickets(10, initial_number: 101, organization: organization) # Tests that it pulls the default location
    #   organization.reload
    #   expect(Appointment.count).to eq 0
    #   expect(organization.tickets.count).to eq 10
    #   expect(organization.tickets.unused.count).to eq 10
    #   ticket1 = organization.tickets.number_ordered.first
    #   ticket2 = organization.tickets.friendly_find(102)
    #   expect(ticket1.number).to eq 101
    #   instance.perform(ticket2.id)
    #   ticket1.reload
    #   expect(ticket1.status).to eq "unused"
    #   ticket2.reload
    #   expect(ticket2.status).to eq "waiting"
    #   expect(organization.tickets.unused.count).to eq 5
    #   expect(organization.tickets.in_line.count).to eq 5
    #   expect(Appointment.count).to eq 2
    #   expect(Appointment.where(creator_kind: "queue_worker").count).to eq 2
    #   ticket3 = organization.tickets.friendly_find(103)
    #   instance.perform(ticket3.id)
    #   ticket2.reload
    #   expect(ticket2.in_line?).to be_truthy
    #   expect(organization.tickets.unused.count).to eq 4
    #   expect(organization.tickets.in_line.count).to eq 6
    #   expect(Appointment.in_line.count).to eq 6
    #   # If passed resolve_earlier_tickets, it marks them resolved
    #   instance.perform(ticket3.id, true)
    #   ticket1.reload
    #   expect(ticket1.status).to eq "unused"
    #   ticket2.reload
    #   expect(ticket2.status).to eq "resolved"
    #   ticket3.reload
    #   expect(ticket3.status).to eq "waiting"
    #   expect(organization.tickets.unused.count).to eq 4
    #   expect(organization.tickets.in_line.count).to eq 5
    #   expect(organization.tickets.resolved.count).to eq 1
    #   expect(Appointment.in_line.count).to eq 2
    #   expect(Appointment.removed.count).to eq 1
    # end
  end
end
