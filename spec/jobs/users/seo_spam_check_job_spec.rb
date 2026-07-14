require "rails_helper"

RSpec.describe Users::SeoSpamCheckJob, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to eq 1.week
  end

  describe "enqueue_workers" do
    let!(:user_shown) { FactoryBot.create(:user_confirmed, show_bikes: true) }
    let!(:user_shown2) { FactoryBot.create(:user_confirmed, show_bikes: true) }
    let!(:user_hidden) { FactoryBot.create(:user_confirmed, show_bikes: false) }

    it "enqueues a job for each show_bikes user" do
      expect(described_class.jobs.count).to eq 0
      instance.perform
      enqueued_ids = described_class.jobs.map { |j| j["args"].first }
      expect(enqueued_ids).to match_array([user_shown.id, user_shown2.id])
    end
  end

  describe "perform" do
    let(:user) { FactoryBot.create(:user_confirmed, show_bikes: true, name:, description:) }
    let(:name) { "Rider Person" }
    let(:description) { "I ride bikes around Chicago and love my Surly." }

    context "ordinary profile" do
      it "does not ban" do
        expect { instance.perform(user.id) }.to_not change(EmailBan, :count)
      end
    end

    context "crypto/gambling references" do
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      it "creates a seo_spam EmailBan" do
        expect { instance.perform(user.id) }.to change(EmailBan, :count).by(1)
        email_ban = EmailBan.last
        expect(email_ban.user_id).to eq user.id
        expect(email_ban.reason).to eq "seo_spam"
        expect(user.reload.email_banned?).to be_truthy
      end
    end

    context "crypto reference only in the profile link" do
      let(:user) do
        FactoryBot.create(:user_confirmed, show_bikes: true,
          my_bikes_hash: {"link_target" => "https://buy-bitcoin-presale.example"})
      end
      it "creates a seo_spam EmailBan" do
        expect { instance.perform(user.id) }.to change(EmailBan, :count).by(1)
        expect(EmailBan.last.reason).to eq "seo_spam"
      end
    end

    context "gibberish profile text" do
      let(:name) { "VhriBJhD1nuwHoI9VhriBJhD1nuwHoI9" }
      let(:description) { "efgBz9pNdd7efgBz9pNdd7 xzkqwrmlbnptvxz" }
      it "creates a seo_spam EmailBan" do
        expect(SpamEstimator.string_spaminess([name, description].join(" ")))
          .to be > SpamEstimator::MARK_SPAM_PERCENT
        expect { instance.perform(user.id) }.to change(EmailBan, :count).by(1)
      end
    end

    context "already email_banned" do
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      before { EmailBan.create!(user:, reason: :honeypot) }
      it "does not create a duplicate ban" do
        expect { instance.perform(user.id) }.to_not change(EmailBan, :count)
      end
    end

    context "banned user" do
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      before { user.update_column(:banned, true) }
      it "does nothing" do
        expect { instance.perform(user.id) }.to_not change(EmailBan, :count)
      end
    end

    context "user no longer show_bikes" do
      let(:description) { "Best online casino and slot gacor bonus, join now!" }
      before { user.update_column(:show_bikes, false) }
      it "does nothing" do
        expect { instance.perform(user.id) }.to_not change(EmailBan, :count)
      end
    end
  end
end
