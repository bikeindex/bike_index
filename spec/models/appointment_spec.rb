require "rails_helper"

RSpec.describe Appointment, type: :model do
  describe "factory" do
    let(:appointment) { FactoryBot.create(:appointment, status: "waiting") }
    it "is valid" do
      expect(appointment.valid?).to be_truthy
      expect(appointment.id).to be_present
      expect(appointment.in_line?).to be_truthy
      expect(appointment.signed_in_user?).to be_falsey
      expect(appointment.virtual_line?).to be_truthy
      expect(appointment.line_entry_timestamp).to be_within(1).of appointment.created_at.to_i
      # And it updates the queue
      expect do
        appointment.update(updated_at: Time.current)
      end.to change(LocationAppointmentsQueueWorker.jobs, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([appointment.location_id])
    end
  end

  describe "line_ordered, move_behind, move_to_back" do
    let!(:appt1) { FactoryBot.create(:appointment, status: "on_deck", created_at: Time.current - 1.hour) }
    let(:organization) { appt1.organization }
    let(:location) { appt1.location }
    # Shuffle the order when they're actually created around a little bit
    let!(:appt4) { FactoryBot.create(:appointment, created_at: Time.current - 10.minutes, organization: organization, location: location) }
    let!(:appt5) { FactoryBot.create(:appointment, organization: organization, location: location) }
    let!(:appt3) { FactoryBot.create(:appointment, created_at: Time.current - 20.minutes, organization: organization, location: location) }
    let!(:appt2) { FactoryBot.create(:appointment, created_at: Time.current - 30.minutes, organization: organization, location: location) }
    it "sorts by line_entry_timestamp" do
      location.reload
      expect(appt1)
      expect(location.appointments.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id])
      # Different than default ordering
      expect(Appointment.pluck(:id)).to_not eq(Appointment.line_ordered.pluck(:id))

      appt2.move_behind!(appt4)
      expect(Appointment.line_ordered.pluck(:id)).to eq([appt1.id, appt3.id, appt4.id, appt2.id, appt5.id])

      # Doing it again doesn't change anything
      appt2.move_behind!(appt4)
      expect(Appointment.line_ordered.pluck(:id)).to eq([appt1.id, appt3.id, appt4.id, appt2.id, appt5.id])

      # Doing it again doesn't change anything
      appt4.move_behind!(appt5)
      expect(Appointment.line_ordered.pluck(:id)).to eq([appt1.id, appt3.id, appt2.id, appt5.id, appt4.id])
    end
  end
end
