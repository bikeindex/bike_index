require "rails_helper"

RSpec.describe Users::RemoveUnconfirmedJob, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to be > 20.hours
  end

  describe "perform" do
    context "with unconfirmed users" do
      let!(:confirmed_old) { FactoryBot.create(:user_confirmed, created_at: Time.current - 1.week) }
      let!(:unconfirmed_old) { FactoryBot.create(:user, created_at: Time.current - 1.week) }
      let!(:unconfirmed) { FactoryBot.create(:user) }
      it "removes old unconfirmed" do
        expect(instance.unconfirmed_users_to_remove.pluck(:id)).to eq([unconfirmed_old.id])
        expect do
          instance.perform
        end.to change(User.unscoped, :count).by(-1)

        expect(User.unscoped.pluck(:id)).to match_array([confirmed_old.id, unconfirmed.id])
      end
    end

    context "with banned_email_domain_users" do
      let!(:user) { FactoryBot.create(:user_confirmed, created_at: Time.current - 1.week, email: "something@zzz.example.com") }
      let!(:user_not_domain) { FactoryBot.create(:user_confirmed, created_at: Time.current - 1.week, email: "other@example.org") }
      let!(:user_pending_domain) { FactoryBot.create(:user_confirmed, created_at: Time.current - 1.week, email: "other@stuff.stuff.com") }
      let(:creator) { FactoryBot.create(:superuser) }
      let!(:email_domain_banned) { FactoryBot.create(:email_domain, status: "banned", domain: "example.com", creator:) }
      let!(:email_domain_pending) { FactoryBot.create(:email_domain, status: "provisional_ban", domain: "stuff.com", creator:) }

      it "removes old unconfirmed" do
        expect do
          instance.perform
        end.to change(User.unscoped, :count).by(-1)

        expect(User.unscoped.pluck(:id)).to match_array([user_not_domain.id, user_pending_domain.id, creator.id])
      end
    end
  end
end
