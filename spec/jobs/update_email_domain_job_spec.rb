require "rails_helper"

RSpec.describe UpdateEmailDomainJob, type: :lib do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 20.hours
  end

  describe "perform" do
    let(:instance) { described_class.new }
    let(:user) { FactoryBot.create(:user_confirmed, email: "example@#{email_domain.domain}") }
    let(:valid_data) do
      {
        broader_domain_exists: false,
        tld: nil,
        is_tld: true,
        domain_resolves: true,
        tld_resolves: true,
        bike_count: 0
      }
    end
    context "bikeindex" do
      let!(:email_domain_at) { FactoryBot.create(:email_domain, domain: "@bikeindex.org") }
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "bikeindex.org") }

      it "updates counts in the cache" do
        expect(user).to be_present
        VCR.use_cassette("UpdateEmailDomainJob-bikeindex") do
          instance.perform(email_domain_at.id)
          expect(email_domain_at.reload.user_count).to eq 1
          expect(email_domain_at.status).to eq "permitted"
          expect(email_domain_at.data).to match_hash_indifferently valid_data.merge(tld: "bikeindex.org", broader_domain_exists: true)

          # Verify that setting no_auto_assign_status
          email_domain.update(data: {no_auto_assign_status: true})
          expect(email_domain.reload.no_auto_assign_status?).to be_truthy
          instance.perform(email_domain.id)
          expect(email_domain.reload.no_auto_assign_status?).to be_truthy
          expect(email_domain.status).to eq "permitted"
        end
      end
    end
    context "@gmail.com" do
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@gmail.com") }
      it "resolves" do
        expect(user).to be_present
        VCR.use_cassette("UpdateEmailDomainJob-gmail") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 1
          expect(email_domain.data).to match_hash_indifferently valid_data.merge(tld: "gmail.com")
          expect(email_domain.status).to eq "permitted"
        end
      end
    end

    context "domain that doesn't resolve" do
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "sisq.unylix.com") }
      let(:target_data) do
        valid_data.merge(tld: "unylix.com",
          is_tld: false,
          domain_resolves: false,
          tld_resolves: false)
      end
      it "makes ban_pending" do
        expect(user).to be_present
        VCR.use_cassette("UpdateEmailDomainJob-unresolved") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 1
          expect(email_domain.data).to match_hash_indifferently target_data
          expect(email_domain.status).to eq "ban_pending"
        end
      end
    end
  end
end
