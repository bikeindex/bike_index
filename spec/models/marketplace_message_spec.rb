require "rails_helper"

RSpec.describe MarketplaceMessage, type: :model do
  describe "factory" do
    let(:marketplace_message) { FactoryBot.create(:marketplace_message) }
    it "is valid" do
      expect(marketplace_message).to be_valid
    end
  end
end
