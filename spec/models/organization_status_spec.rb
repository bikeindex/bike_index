require "rails_helper"

RSpec.describe OrganizationStatus, type: :model do
  describe "factory" do
    let(:organization_status) { FactoryBot.create(:organization_status) }
    it "is valid" do
      expect(organization_status).to be_valid
      expect(organization_status.current?).to be_truthy
    end
  end

  describe "at_time" do
    it "returns matching statuses" do
      fail
    end
  end
end
