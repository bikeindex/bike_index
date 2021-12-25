require 'rails_helper'

RSpec.describe UserRegistrationOrganization, type: :model do
  describe "factories" do
    let(:user_registration_organization) { FactoryBot.create(:user_registration_organization) }
    it "is valid" do
      expect(user_registration_organization).to be_valid
    end
  end

  describe "calculated_bike_ids" do
    context "not set" do
      it "uses ownerships"
    end
    context "all bikes" do
      it "does all"
    end
    context "set and bike_ids" do
      it "does it"
    end
  end
end
