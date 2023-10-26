require "rails_helper"

RSpec.describe LoggedSearch, type: :model do
  describe "ENDPOINT_ENUM" do
    let(:endpoint_enum) { LoggedSearch::ENDPOINT_ENUM }
    it "has separate values" do
      expect(endpoint_enum.keys.count).to eq endpoint_enum.values.uniq.count
    end
  end
  describe "factory" do
    let(:logged_search) { FactoryBot.create(:logged_search) }
    it "is valid" do
      expect(logged_search).to be_valid
    end
  end
end
