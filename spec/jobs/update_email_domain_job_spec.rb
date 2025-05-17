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
    let!(:user) { FactoryBot.create(:user_confirmed, email: "example@#{user_domain}") }
    let(:user2) { FactoryBot.create(:user_confirmed, email: "example2@#{user_domain}") }
    let(:valid_data) do
      {
        broader_domain_exists: false,
        tld: domain,
        is_tld: true,
        subdomain_count: 0,
        domain_resolves: true,
        tld_resolves: true,
        bike_count: 0,
        b_param_count: 0,
        notification_count: 0,
        bike_count_pos: 0,
        user_count_donated: 0
      }
    end
    let(:domain) { "bikeindex.org" }
    let(:user_domain) { domain }
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "@#{user_domain}") }
    before { stub_const("EmailDomain::EMAIL_MIN_COUNT", 1) }

    context "bikeindex" do
      let!(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "@example.#{domain}") }
      let!(:email_domain_bare) { FactoryBot.create(:email_domain, domain:) }

      it "updates counts in the cache" do
        VCR.use_cassette("Update-Email-Domain-Job_bikeindex") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 4 # Because users created for email domains
          expect(email_domain.status).to eq "permitted"
          expect(email_domain.tld_matches_subdomains?).to be_falsey
          # expect(email_domain.data.except("spam_score")).to match_hash_indifferently valid_data.merge(broader_domain_exists: true, subdomain_count: 1)
          expect(email_domain.data.except("spam_score")).to match_hash_indifferently valid_data.merge(subdomain_count: 1)
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
          expect(email_domain_bare.data.except("spam_score")).to match_hash_indifferently(valid_data.merge(subdomain_count: 1, no_auto_assign_status: true))
        end
      end
    end

    context "invalid_domain" do
      let!(:email_domain) { EmailDomain.invalid_domain_record }
      let(:domain) { 'fffff\.com' }
      let(:invalid_data) do
        valid_data.merge(domain_resolves: false, tld_resolves: false, tld: email_domain.domain)
      end
      it "updates counts in the cache" do
        expect(EmailDomain.find_matching_domain(user_domain)&.id).to eq email_domain.id
        instance.perform(email_domain.id)
        expect(email_domain.reload.user_count).to eq 0 # invalid_domain doesn't match
        expect(email_domain.status).to eq "banned"
        expect(email_domain.tld_matches_subdomains?).to be_truthy
        expect(EmailDomain.subdomain.pluck(:id)).to match_array([])
        expect(email_domain.calculated_subdomains.pluck(:id)).to eq([])
        expect(email_domain.data.except("spam_score")).to match_hash_indifferently invalid_data
      end
    end

    context "@gmail.com" do
      let(:domain) { "gmail.com" }
      let!(:bike2) { FactoryBot.create(:bike_lightspeed_pos, owner_email: "example@#{domain}") }
      let(:target_data) { valid_data.merge(bike_count: 1, bike_count_pos: 1) }
      it "resolves" do
        VCR.use_cassette("Update-Email-Domain-Job_gmail") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 1
          expect(email_domain.has_ban_blockers?).to be_truthy
          expect(email_domain.data.except("spam_score")).to match_hash_indifferently target_data
          expect(email_domain.status).to eq "permitted"
          expect(email_domain.spam_score).to be > 5
        end
      end
      context "with domain starting out provisional_ban" do
        before { email_domain.update(status: :provisional_ban) }

        it "marks it permitted" do
          expect(email_domain.reload.status).to eq "provisional_ban"

          VCR.use_cassette("Update-Email-Domain-Job_gmail") do
            instance.perform(email_domain.id)
            expect(email_domain.reload.user_count).to eq 1
            expect(email_domain.has_ban_blockers?).to be_truthy
            expect(email_domain.data.except("spam_score")).to match_hash_indifferently target_data
            expect(email_domain.status).to eq "permitted"
            expect(email_domain.spam_score).to be > 5
          end
        end
      end
    end

    context "VALIDATE_WITH_SENDGRID" do
      let(:domain) { "nkk.co.za" }
      let!(:user2) { FactoryBot.create(:user_confirmed, email: "malaysia_lloyd57@nkk.co.za") }
      let(:target_sendgrid_keys) { %w[checks email host ip_address local score source verdict] }
      before { stub_const("UpdateEmailDomainJob::VALIDATE_WITH_SENDGRID", true) }

      it "doesn't resolve, but bike makes it permitted" do
        VCR.use_cassette("Update-Email-Domain-Job_co.za") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 2
          expect(email_domain.bike_count).to eq 0

          expect(email_domain.data.except("sendgrid_validations", "spam_score"))
            .to match_hash_indifferently valid_data.merge(domain_resolves: false, tld_resolves: false)
          expect(email_domain.data.dig("sendgrid_validations", user2.email).keys.sort).to eq target_sendgrid_keys
          expect(email_domain.spam_score).to be < 2
          expect(email_domain.status).to eq "provisional_ban"
        end
      end
    end

    context "@msn.com" do
      let(:domain) { "msn.com" }
      let!(:bike) { FactoryBot.create(:bike, owner_email: "something@#{domain}") }
      let!(:payment) { FactoryBot.create(:payment, user:) }
      let(:msn_data) do
        valid_data.merge(domain_resolves: false, tld_resolves: false, bike_count: 1, user_count_donated: 1)
      end

      it "doesn't resolve, but bike makes it permitted" do
        expect(User.donated.pluck(:id)).to eq([user.id])
        VCR.use_cassette("Update-Email-Domain-Job_msn") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 1
          expect(email_domain.bike_count).to eq 1
          expect(email_domain.data.except("spam_score")).to match_hash_indifferently msn_data
          expect(email_domain.status).to eq "permitted"
          expect(email_domain.has_ban_blockers?).to be_truthy
          expect(email_domain.spam_score).to be >= 4
        end
      end
    end

    context "domain that doesn't resolve" do
      let(:domain) { "unylix.com" }
      let(:user_domain) { "sisq.unylix.com" }
      let(:target_data) do
        valid_data.merge(is_tld: false,
          domain_resolves: false,
          tld_resolves: false)
      end
      before { expect(user2).to be_present } # So EMAIL_MIN_COUNT passes

      it "makes provisional_ban" do
        expect(email_domain.reload.calculated_users.count).to eq 2

        VCR.use_cassette("Update-Email-Domain-Job_unresolved") do
          instance.perform(email_domain.id)
          expect(email_domain.reload.user_count).to eq 2
          expect(email_domain.has_ban_blockers?).to be_falsey
          expect(email_domain.data.except("spam_score")).to match_hash_indifferently target_data
          expect(email_domain.status).to eq "provisional_ban"
          expect(described_class).to_not have_enqueued_sidekiq_job
          expect(email_domain.spam_score).to be < 2
        end
      end

      context "create_tld_subdomain_count" do
        let!(:email_domain_2) { FactoryBot.create(:email_domain, domain: "ffff.#{domain}") }
        let!(:email_domain_3) { FactoryBot.create(:email_domain, domain: "zsss.#{domain}") }
        let!(:email_domain_4) { FactoryBot.create(:email_domain, domain: "dd.zs.#{domain}") }
        it "makes tld domain" do
          VCR.use_cassette("Update-Email-Domain-Job_unresolved") do
            expect(EmailDomain.count).to eq 4
            Sidekiq::Job.clear_all
            instance.perform(email_domain.id)
            expect(email_domain.reload.has_ban_blockers?).to be_falsey
            expect(email_domain.auto_bannable?).to be_truthy
            expect(email_domain.reload.status).to eq "provisional_ban"

            expect(EmailDomain.count).to eq 5
            email_domain_tld = EmailDomain.order(:id).last
            expect(EmailDomain.tld_matches_subdomains.pluck(:id)).to eq([email_domain_tld.id])
            expect(email_domain_tld.status).to eq "provisional_ban"
            Sidekiq::Job.clear_all
            instance.perform(email_domain_tld.id)
            expect(email_domain_tld.reload.status).to eq "provisional_ban"
            expect(described_class.jobs.map { |j| j["args"] }.flatten).to match_array([email_domain_2.id, email_domain_3.id, email_domain_4.id])
            expect(email_domain_tld.calculated_users.count).to eq 2
            expect(EmailDomain.count).to eq 5
            described_class.drain
            expect(EmailDomain.provisional_ban.count).to eq 5
            # if the TLD is banned, delete all the subs and the users
            email_domain_tld.update(status: "banned")
            instance.perform(email_domain_tld.id)
            expect(EmailDomain.count).to eq 1
            expect(email_domain_tld.reload.calculated_users.count).to eq 0
          end
        end
        context "with @tld" do
          let!(:email_domain_at) { FactoryBot.create(:email_domain, domain: "@#{domain}") }

          it "makes tld domain" do
            expect(email_domain_at.reload.tld_matches_subdomains?).to be_falsey
            expect(email_domain_at.tld?).to be_truthy

            VCR.use_cassette("Update-Email-Domain-Job_unresolved") do
              expect(EmailDomain.count).to eq 5
              instance.perform(email_domain.id)

              expect(email_domain.reload.status).to eq "provisional_ban"

              expect(EmailDomain.count).to eq 6
            end
            new_email_domain = EmailDomain.order(:id).last
            expect(new_email_domain.domain).to eq domain
            expect(new_email_domain.status).to eq "provisional_ban"

            # If we ignore the new domain, it doesn't get created again
            new_email_domain.update(status: "ignored")

            VCR.use_cassette("Update-Email-Domain-Job_unresolved") do
              expect { instance.perform(email_domain.id) }.to_not change(EmailDomain, :count)
            end
          end

          context "with broader" do
            let!(:email_domain_ignored) { FactoryBot.create(:email_domain, domain: "lix.com", status: :ignored) }
            it "makes tld domain" do
              expect(email_domain_at.reload.tld_matches_subdomains?).to be_falsey
              expect(email_domain_at.tld?).to be_truthy

              VCR.use_cassette("Update-Email-Domain-Job_unresolved") do
                expect(EmailDomain.count).to eq 6
                instance.perform(email_domain.id)

                expect(email_domain.reload.status).to eq "provisional_ban"

                expect(EmailDomain.count).to eq 7
              end
              expect(EmailDomain.order(:id).last.domain).to eq domain
            end
          end
        end
      end
    end
  end
end
