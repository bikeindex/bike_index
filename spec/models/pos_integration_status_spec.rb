require "rails_helper"

RSpec.describe PosIntegrationStatus, type: :model do
  describe "factory" do
    let(:pos_integration_status) { FactoryBot.create(:pos_integration_status) }
    it "is valid" do
      expect(pos_integration_status).to be_valid
      expect(pos_integration_status.current?).to be_truthy
    end
  end
end
