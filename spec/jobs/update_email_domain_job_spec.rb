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
    let!(:user) { FactoryBot.create(:user_confirmed, email: "example@#{domain}") }
    let(:valid_data) do
      {
        broader_domain_exists: false,
        tld: domain,
        is_tld: true,
        subdomain_count: 0,
        domain_resolves: true,
        tld_resolves: true,
        bike_count: 0
      }
    end
    let(:domain) { "bikeindex.org" }
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@#{domain}") }

    context "bikeindex" do
      let!(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "@example.#{domain}") }
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@#{domain}") }
      let!(:email_domain_bare) { FactoryBot.create(:email_domain, domain:) }

      it "updates counts in the cache" do
        VCR.use_cassette("UpdateEmailDomainJob-bikeindex") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 1
          expect(email_domain.status).to eq "permitted"
          expect(email_domain.tld_matches_subdomains?).to be_falsey
          expect(email_domain.data).to match_hash_indifferently valid_data.merge(broader_domain_exists: true, subdomain_count: 1)
          expect(EmailDomain.tld.pluck(:id)).to match_array([email_domain.id, email_domain_bare.id])
          expect(EmailDomain.subdomain.pluck(:id)).to match_array([email_domain_sub.id])
          expect(email_domain.calculated_subdomains.pluck(:id)).to eq([email_domain_sub.id])
          expect(email_domain_bare.calculated_subdomains.pluck(:id)).to eq([email_domain_sub.id])
          expect(email_domain_sub.calculated_subdomains.pluck(:id)).to eq([])

          # Verify that setting no_auto_assign_status
          email_domain_bare.update(data: {no_auto_assign_status: true})
          expect(email_domain_bare.tld_matches_subdomains?).to be_truthy
          expect(email_domain_bare.reload.no_auto_assign_status?).to be_truthy
          instance.perform(email_domain_bare.id)
          expect(email_domain_bare.reload.no_auto_assign_status?).to be_truthy
          expect(email_domain_bare.status).to eq "permitted"
          expect(email_domain_bare.data).to match_hash_indifferently(valid_data.merge(subdomain_count: 1, no_auto_assign_status: true))
        end
      end
    end

    context "@gmail.com" do
      let(:domain) { "gmail.com" }
      it "resolves" do
        VCR.use_cassette("UpdateEmailDomainJob-gmail") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 1
          expect(email_domain.data).to match_hash_indifferently valid_data.merge
          expect(email_domain.status).to eq "permitted"
        end
      end
    end

    context "@msn.com" do
      let(:domain) { "msn.com" }
      let!(:bike) { FactoryBot.create(:bike, owner_email: "something@#{domain}") }
      let(:msn_data) do
        valid_data.merge(domain_resolves: false, tld_resolves: false, bike_count: 1)
      end

      it "doesn't resolve, but bike makes it permitted" do
        VCR.use_cassette("UpdateEmailDomainJob-msn") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 1
          expect(email_domain.reload.bike_count).to eq 1
          expect(email_domain.data).to match_hash_indifferently msn_data
          expect(email_domain.status).to eq "permitted"
        end
      end
    end

    context "domain that doesn't resolve" do
      let(:domain) { "unylix.com" }
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "sisq.#{domain}") }
      let(:target_data) do
        valid_data.merge(is_tld: false,
          domain_resolves: false,
          tld_resolves: false)
      end
      it "makes ban_pending" do
        VCR.use_cassette("UpdateEmailDomainJob-unresolved") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 0
          expect(email_domain.data).to match_hash_indifferently target_data
          expect(email_domain.status).to eq "ban_pending"
          expect(described_class).to_not have_enqueued_sidekiq_job
        end
      end

      context "create_tld_subdomain_count" do
        let!(:email_domain_2) { FactoryBot.create(:email_domain, domain: "ffff.#{domain}") }
        let!(:email_domain_3) { FactoryBot.create(:email_domain, domain: "zsss.#{domain}") }
        let!(:email_domain_4) { FactoryBot.create(:email_domain, domain: "dd.zs.#{domain}") }
        it "makes tld domain" do
          VCR.use_cassette("UpdateEmailDomainJob-unresolved") do
            expect(EmailDomain.count).to eq 4
            instance.perform(email_domain.id)

            expect(described_class.auto_pending_ban?(email_domain.reload)).to be_truthy
            expect(email_domain.reload.status).to eq "ban_pending"

            expect(EmailDomain.count).to eq 5
            email_domain_tld = EmailDomain.order(:id).last
            expect(EmailDomain.tld_matches_subdomains.pluck(:id)).to eq([email_domain_tld.id])
            expect(email_domain_tld.status).to eq "permitted"
            expect(described_class).to have_enqueued_sidekiq_job(email_domain_tld.id)
          end
        end
        context "with @tld" do
          let!(:email_domain_at) { FactoryBot.create(:email_domain, domain: "@#{domain}") }

          it "makes tld domain" do
            expect(email_domain_at.reload.tld_matches_subdomains?).to be_falsey
            expect(email_domain_at.tld?).to be_truthy

            VCR.use_cassette("UpdateEmailDomainJob-unresolved") do
              expect(EmailDomain.count).to eq 5
              instance.perform(email_domain.id)

              expect(email_domain.reload.status).to eq "ban_pending"

              expect(EmailDomain.count).to eq 6
              EmailDomain.order(:id).last
            end
          end
        end
      end
    end
  end
end
