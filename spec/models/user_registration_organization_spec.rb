require 'rails_helper'

RSpec.describe UserRegistrationOrganization, type: :model do
  describe "factories" do
    let(:user_registration_organization) { FactoryBot.create(:user_registration_organization) }
    it "is valid" do
      expect(user_registration_organization).to be_valid
    end
  end
end
