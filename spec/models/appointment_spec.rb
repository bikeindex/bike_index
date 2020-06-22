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
      # And it updates the queue
      expect do
        appointment.update(updated_at: Time.current)
      end.to change(LocationAppointmentsQueueWorker.jobs, :count)
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([appointment.location_id])
    end
  end
end
