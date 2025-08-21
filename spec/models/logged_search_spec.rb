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
    context "with associations" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:user) }
      let(:logged_search1) { FactoryBot.create(:logged_search, organization: organization) }
      let(:logged_search2) { FactoryBot.create(:logged_search, user: user) }
      it "is valid" do
        expect(logged_search1).to be_valid
        expect(logged_search1.reload.organization_id).to eq organization.id

        expect(logged_search2).to be_valid
        expect(logged_search2.reload.user_id).to eq user.id
      end
    end
  end
end
