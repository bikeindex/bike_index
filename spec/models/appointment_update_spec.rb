require "rails_helper"

RSpec.describe AppointmentUpdate, type: :model do
  describe "update appointment queue" do
    let(:appointment) { FactoryBot.create(:appointment) }
    let(:appointment_update) { FactoryBot.build(:appointment_update, appointment: appointment, status: "finished") }
    it "only enqueues on create" do
      expect(appointment.appointment_updates.count).to eq 0
      expect do
        appointment_update.save
      end.to change(LocationAppointmentsQueueWorker.jobs, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([appointment.location_id, appointment.id])
      appointment.reload
      expect(appointment.appointment_updates.count).to eq 1

      # It doesn't enqueue when updating or destroying (the updates should be immutable anyway)
      expect do
        appointment_update.update(updated_at: Time.current)
        appointment_update.destroy
      end.to_not change(LocationAppointmentsQueueWorker.jobs, :count)
    end
  end
end
