require "rails_helper"

RSpec.describe SeoSpaminess do
  describe "estimate_user" do
    let(:user) { User.new(show_bikes: true, name:, description:) }
    let(:name) { "Rider Person" }
    let(:description) { "I ride bikes around Chicago and love my Surly." }

    it "is low for an ordinary profile" do
      expect(described_class.estimate_user(user)).to be < SeoSpaminess::MARK_SPAM_PERCENT
    end

    it "is 0 for a blank user" do
      expect(described_class.estimate_user(nil)).to eq 0
      expect(described_class.estimate_user(User.new)).to eq 0
    end

    context "crypto/gambling references" do
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      it "is 100" do
        expect(described_class.estimate_user(user)).to eq 100
      end
    end

    context "reference only in the profile link" do
      let(:user) do
        User.new(show_bikes: true, my_bikes_hash: {"link_target" => "https://buy-bitcoin-presale.example"})
      end
      it "is 100" do
        expect(described_class.estimate_user(user)).to eq 100
      end
    end

    context "gibberish profile text" do
      let(:name) { "VhriBJhD1nuwHoI9VhriBJhD1nuwHoI9" }
      let(:description) { "efgBz9pNdd7efgBz9pNdd7 xzkqwrmlbnptvxz" }
      it "is above the spam threshold" do
        expect(described_class.estimate_user(user)).to be > SeoSpaminess::MARK_SPAM_PERCENT
      end
    end

    context "user owns bikes" do
      let(:user) { FactoryBot.create(:user_confirmed, show_bikes: true, name:, description:) }
      let(:description) { "Best online casino and slot gacor bonus, join now!" }

      context "one bike" do
        let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
        it "subtracts 30" do
          expect(described_class.estimate_user(user.reload)).to eq 70
        end
      end

      context "multiple bikes" do
        let!(:bikes) { FactoryBot.create_list(:bike, 2, :with_ownership_claimed, user:) }
        it "subtracts 50" do
          expect(described_class.estimate_user(user.reload)).to eq 50
        end
      end
    end
  end
end
