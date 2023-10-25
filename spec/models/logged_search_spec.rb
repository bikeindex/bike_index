require 'rails_helper'

RSpec.describe LoggedSearch, type: :model do
  describe "factory" do
    let(:logged_search) { FactoryBot.create(:logged_search) }
    it "is valid" do
      expect(logged_search).to be_valid
    end
  end
end
