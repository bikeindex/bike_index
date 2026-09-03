require "rails_helper"

RSpec.describe UserJobs::SeoSpamCheckJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:user) { FactoryBot.create(:user_confirmed, show_bikes: true, name:, description:) }
    let(:name) { "Rider Person" }
    let(:description) { "I ride bikes around Chicago and love my Surly." }

    context "ordinary profile" do
      it "does not ban" do
        expect { instance.perform(user.id) }.to_not change(UserBan, :count)
        expect(user.reload.banned?).to be_falsey
      end
    end

    context "crypto/gambling references" do
      let(:description) { "Best online casino, poker, blackjack, and roulette bonus, join now!" }
      it "bans the user for seo_spam, recording the estimate and matched terms" do
        expect { instance.perform(user.id) }.to change(UserBan, :count).by(1)
        user_ban = UserBan.last
        expect(user_ban.user_id).to eq user.id
        expect(user_ban.reason).to eq "seo_spam"
        expect(user_ban.description).to match(/\AEstimate \d+\. matched: /)
        expect(user_ban.description).to include "casino"
        expect(user.reload.banned?).to be_truthy
      end
      it "accepts the user passed directly as the second arg" do
        expect { instance.perform(user.id, user) }.to change(UserBan, :count).by(1)
        expect(UserBan.last.reason).to eq "seo_spam"
      end
    end

    context "crypto reference only in the profile link" do
      let(:user) do
        FactoryBot.create(:user_confirmed, show_bikes: true,
          my_bikes_hash: {"link_target" => "https://bitcoin-ethereum-casino-poker-presale.example"})
      end
      it "bans the user for seo_spam" do
        expect { instance.perform(user.id) }.to change(UserBan, :count).by(1)
        expect(UserBan.last.reason).to eq "seo_spam"
        expect(user.reload.banned?).to be_truthy
      end
    end

    context "gibberish profile text" do
      let(:name) { "VhriBJhD1nuwHoI9VhriBJhD1nuwHoI9" }
      let(:description) { "efgBz9pNdd7efgBz9pNdd7 xzkqwrmlbnptvxz" }
      it "bans the user for seo_spam, recording the estimate without a matched-terms list" do
        expect(SpamEstimator::Text.estimate([name, description].join(" ")))
          .to be > SpamEstimator::User::MARK_SPAM_PERCENT
        expect { instance.perform(user.id) }.to change(UserBan, :count).by(1)
        expect(UserBan.last.description).to match(/\AEstimate \d+\z/)
      end
    end

    context "already banned user" do
      let(:description) { "Best online casino, poker, blackjack, and roulette bonus, join now!" }
      before { user.update_column(:banned, true) }
      it "does nothing" do
        expect { instance.perform(user.id) }.to_not change(UserBan, :count)
      end
    end

    context "user no longer show_bikes" do
      let(:description) { "Best online casino, poker, blackjack, and roulette bonus, join now!" }
      before { user.update_column(:show_bikes, false) }
      it "does nothing" do
        expect { instance.perform(user.id) }.to_not change(UserBan, :count)
      end
    end
  end
end
