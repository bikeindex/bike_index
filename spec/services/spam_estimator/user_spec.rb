require "rails_helper"

RSpec.describe SpamEstimator::User do
  describe "estimate" do
    let(:user) { User.new(show_bikes: true, name:, description:) }
    let(:name) { "Rider Person" }
    let(:description) { "I ride bikes around Chicago and love my Surly." }

    it "is low for an ordinary profile" do
      expect(described_class.estimate(user)).to be < SpamEstimator::User::MARK_SPAM_PERCENT
    end

    it "is 0 for a blank user" do
      expect(described_class.estimate(nil)).to eq 0
      expect(described_class.estimate(User.new)).to eq 0
    end

    context "crypto/gambling references" do
      # links are regex-scanned but not scored as text, so the score is exactly 30 per reference
      let(:user) { User.new(show_bikes: true, my_bikes_hash: {"link_target" => link_target}) }

      context "a single reference" do
        let(:link_target) { "https://buy-bitcoin.example" }
        it "adds 30, staying below the threshold" do
          expect(described_class.estimate(user)).to eq 30
        end
      end

      context "several references" do
        let(:link_target) { "https://bitcoin-ethereum-casino-poker.example" }
        it "adds 30 each, clamped to 100" do
          expect(described_class.estimate(user)).to eq 100
        end
      end
    end

    context "Indonesian gambling profile" do
      let(:name) { "LGO234" }
      let(:description) { "LGO234 merupakan situs resmi slot gacor ternama, terpercaya dan gampang menang" }

      it "is above the spam threshold" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "Vietnamese gambling profile" do
      let(:name) { "MU99" }
      let(:description) { "Mu99 là link truy cập nhà cái Mu88, cá cược trực tuyến uy tín" }

      it "is above the spam threshold" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "real names that contain spam terms as substrings" do
      # usernames are auto-generated random strings, so substring matching would ban real people
      it "does not count them as references" do
        %w[Judith Hagen Sloth Donohue Totonchy Sexton Bolanos].each do |real_name|
          expect(described_class.estimate(User.new(show_bikes: true, name: real_name, description:)))
            .to be < SpamEstimator::User::MARK_SPAM_PERCENT
        end
      end
    end

    context "gibberish description" do
      let(:description) { "efgBz9pNdd7efgBz9pNdd7 xzkqwrmlbnptvxz" }
      it "is above the spam threshold" do
        expect(described_class.estimate(user)).to be > SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "gibberish only in name/username (weighted lightly)" do
      let(:user) { User.new(show_bikes: true, name: "VhriBJhD1nuwHoI9", username: "efgBz9pNdd7efgBz9", description:) }
      it "stays below the threshold" do
        expect(described_class.estimate(user)).to be < SpamEstimator::User::MARK_SPAM_PERCENT
      end
    end

    context "seo_spam_matches" do
      let(:user) { User.new(show_bikes: true, title: "Nhà cái uy tín", description: "nha cai casino") }

      it "tallies matched terms, normalizing case and diacritics" do
        expect(described_class.seo_spam_matches(user)).to eq({"nha cai" => 2, "uy tin" => 1, "casino" => 1})
      end

      it "is empty for a blank user" do
        expect(described_class.seo_spam_matches(nil)).to eq({})
        expect(described_class.seo_spam_matches(User.new)).to eq({})
      end
    end

    context "user owns bikes" do
      # 2 link references keep the base well under the clamp, so the reduction is observable
      let(:user) do
        FactoryBot.create(:user_confirmed, show_bikes: true,
          my_bikes_hash: {"link_target" => "https://bitcoin-ethereum.example"})
      end

      it "subtracts 30 for one bike and 50 for two" do
        base = described_class.estimate(user)
        FactoryBot.create(:bike, :with_ownership_claimed, user:)
        expect(described_class.estimate(user.reload)).to eq(base - 30)
        FactoryBot.create(:bike, :with_ownership_claimed, user:)
        expect(described_class.estimate(user.reload)).to eq(base - 50)
      end
    end
  end
end
