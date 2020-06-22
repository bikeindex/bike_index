require "rails_helper"

RSpec.describe AppointmentConfiguration, type: :model do
  describe "factory" do
    let(:appointment_configuration) { FactoryBot.create(:appointment_configuration, customers_on_deck_count: -1) }
    let(:organization) { appointment_configuration.organization }
    let(:location) { organization.locations.first }
    let(:default_reasons) { ["Bike purchase", "Other purchase", "Service"] }
    it "is valid" do
      appointment_configuration.reload
      expect(appointment_configuration.id).to be_present
      expect(appointment_configuration.virtual_line_on?).to be_truthy
      expect(appointment_configuration.reasons).to match_array(default_reasons)
      expect(appointment_configuration.location_id).to eq location.id
      expect(appointment_configuration.customers_on_deck_count).to eq 0
      expect(location.virtual_line_on?).to be_truthy
      expect(organization.appointment_functionality_enabled?).to be_truthy
      appointment_configuration.update(virtual_line_on: false)
      location.reload
      expect(location.virtual_line_on?).to be_falsey
      # Because this is about access, not whether it's on
      expect(organization.appointment_functionality_enabled?).to be_truthy
      # And it updates the queue
      expect do
        appointment_configuration.update(updated_at: Time.current)
      end.to change(LocationAppointmentsQueueWorker.jobs, :count)
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([location.id])
    end
  end
end
