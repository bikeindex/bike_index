require "rails_helper"

RSpec.describe BikeOrganization, type: :model do
  describe "can_edit_claimed" do
    let(:bike_organization) { BikeOrganization.new }
    it "assigns correctly" do
      expect(bike_organization.can_edit_claimed).to be_truthy
      bike_organization.can_edit_claimed = false
      expect(bike_organization.can_edit_claimed).to be_falsey
      expect(bike_organization.can_not_edit_claimed).to be_truthy
    end
  end
end
