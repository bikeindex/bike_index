require "rails_helper"

RSpec.describe LocationAppointmentsQueueWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let!(:appt1) { FactoryBot.create(:appointment, status: "on_deck", line_entry_timestamp: (Time.current - 45.minutes).to_i) }
    let(:organization) { appt1.organization }
    let(:location) { appt1.location }
    let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, organization: organization, location: location, customers_on_deck_count: 1) }
    # Shuffle the order when they're actually created around a little bit
    let!(:appt4) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 10.minutes).to_i, organization: organization, location: location) }
    let!(:appt5) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 5.minutes).to_i, organization: organization, location: location) }
    let!(:appt3) { FactoryBot.create(:appointment, status: "on_deck", line_entry_timestamp: (Time.current - 20.minutes).to_i, organization: organization, location: location) }
    let!(:appt2) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 30.minutes).to_i, organization: organization, location: location) }
    it "sets the correct number of appointments on deck" do
      expect(location.appointment_configuration).to be_blank
      expect(Appointment.on_deck.line_ordered.pluck(:id)).to eq([appt1.id, appt3.id])
      expect(Appointment.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id])
      # Doesn't change anything, because there is no appointment_configuration
      instance.perform(location.id)
      expect(Appointment.on_deck.line_ordered.pluck(:id)).to eq([appt1.id, appt3.id])
      expect(Appointment.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id])
      # With appointment_configuration in place, it makes only 1 be on_deck
      expect(appointment_configuration).to be_present
      expect do
        instance.perform(location.id)
      end.to_not change(described_class.jobs, :count) # Ensure we aren't re-enqueueing
      expect(Appointment.on_deck.line_ordered.pluck(:id)).to eq([appt1.id])
      expect(Appointment.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id])

      # Try it with a larger customers on deck count
      appointment_configuration.update(customers_on_deck_count: 3)
      Sidekiq::Worker.clear_all
      # Test the actual process to make sure it works out
      Sidekiq::Testing.inline! do
        expect(appt1.appointment_updates.count).to eq 0
        appt1.record_status_update(new_status: "being_helped")
        appt1.reload
        expect(appt1.being_helped?).to be_truthy
        expect(appt1.appointment_updates.count).to eq 1
        appointment_update = appt1.appointment_updates.last
        expect(appointment_update.status).to eq "being_helped"
        expect(appointment_update.user_id).to be_blank
        expect(appointment_update.creator_kind).to eq "no_user"
        expect(Appointment.on_deck.line_ordered.pluck(:id)).to eq([appt2.id, appt3.id, appt4.id])
        expect(Appointment.in_line.pluck(:id)).to eq([appt2.id, appt3.id, appt4.id, appt5.id])

        # Try updating another one
        appt4.record_status_update(new_status: "abandoned", updator_kind: "signed_in_user", updator_id: 12)
        appointment_update2 = appt4.appointment_updates.last
        expect(appointment_update2.status).to eq "abandoned"
        expect(appointment_update2.user_id).to eq 12
        expect(appointment_update2.creator_kind).to eq "signed_in_user"
        expect(Appointment.on_deck.line_ordered.pluck(:id)).to eq([appt2.id, appt3.id, appt5.id])
        expect(Appointment.in_line.pluck(:id)).to eq([appt2.id, appt3.id, appt5.id])

        # and ensure it doesn't break when their are fewer than the customers_on_deck_count
        appt3.record_status_update(new_status: "abandoned")
        expect(Appointment.on_deck.line_ordered.pluck(:id)).to eq([appt2.id, appt5.id])
        expect(Appointment.in_line.pluck(:id)).to eq([appt2.id, appt5.id])
      end
    end
  end
end
