require "rails_helper"

RSpec.describe UpdateEmailDomainJob, type: :lib do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 20.hours
  end

  describe "perform" do
    let!(:email_domain_at) { FactoryBot.create(:email_domain, domain: "@bikeindex.org") }
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "bikeindex.org") }
    let!(:user) { FactoryBot.create(:user_confirmed, email: "example@bikeindex.org") }
    let(:target_data) do
      {
        broader_domain_exists: true,
        tld: "bikeindex.org",
        is_tld: true
      }
    end

    it "updates counts in the cache" do
      described_class.new.perform(email_domain_at.id)
      expect(email_domain_at.reload.user_count).to eq 1
      expect(email_domain_at.data).to match_hash_indifferently target_data
    end
  end
end
