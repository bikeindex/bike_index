require "rails_helper"

RSpec.describe Users::SeoSpamCheckJob, type: :job do
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
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      it "bans the user for seo_spam" do
        expect { instance.perform(user.id) }.to change(UserBan, :count).by(1)
        user_ban = UserBan.last
        expect(user_ban.user_id).to eq user.id
        expect(user_ban.reason).to eq "seo_spam"
        expect(user.reload.banned?).to be_truthy
      end
    end

    context "crypto reference only in the profile link" do
      let(:user) do
        FactoryBot.create(:user_confirmed, show_bikes: true,
          my_bikes_hash: {"link_target" => "https://buy-bitcoin-presale.example"})
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
      it "bans the user for seo_spam" do
        expect(SpamEstimator::String.string_spaminess([name, description].join(" ")))
          .to be > SpamEstimator::MARK_SPAM_PERCENT
        expect { instance.perform(user.id) }.to change(UserBan, :count).by(1)
      end
    end

    context "already banned user" do
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      before { user.update_column(:banned, true) }
      it "does nothing" do
        expect { instance.perform(user.id) }.to_not change(UserBan, :count)
      end
    end

    context "user no longer show_bikes" do
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      before { user.update_column(:show_bikes, false) }
      it "does nothing" do
        expect { instance.perform(user.id) }.to_not change(UserBan, :count)
      end
    end
  end
end
