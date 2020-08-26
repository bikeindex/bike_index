require "rails_helper"

RSpec.describe AppointmentUpdate, type: :model do
  describe "status_humanized" do
    let(:appointment) { FactoryBot.create(:appointment) }
    let(:appointment_update) { appointment.record_status_update(new_status: "abandoned") }
    it "returns humanized status" do
      expect(appointment_update.status_humanized).to eq "Left without being helped"
    end
  end
end
