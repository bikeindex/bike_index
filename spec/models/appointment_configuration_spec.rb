require "rails_helper"

RSpec.describe AppointmentConfiguration, type: :model do
  describe "factory" do
    let(:appointment_configuration) { FactoryBot.create(:appointment_configuration) }
    let(:organization) { appointment_configuration.organization }
    let(:location) { organization.locations.first }
    let(:default_reasons) { ["Bike purchase", "Other purchase", "Service"] }
    it "is valid" do
      appointment_configuration.reload
      expect(appointment_configuration.id).to be_present
      expect(appointment_configuration.virtual_line_enabled?).to be_truthy
      expect(appointment_configuration.reasons).to match_array(default_reasons)
      expect(organization.appointments_enabled?).to be_truthy
      expect(appointment_configuration.location_id).to eq location.id
      expect(location.virtual_line_enabled?).to be_truthy
      appointment_configuration.update(virtual_line_enabled: false)
      expect(organization.appointments_enabled?).to be_truthy
      expect(location.virtual_line_enabled?).to be_falsey
    end
  end
end
