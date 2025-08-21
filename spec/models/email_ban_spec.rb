# == Schema Information
#
# Table name: email_bans
#
#  id         :bigint           not null, primary key
#  end_at     :datetime
#  reason     :integer
#  start_at   :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_email_bans_on_user_id  (user_id)
#
require "rails_helper"

RSpec.describe EmailBan, type: :model do
  describe "factory" do
    let(:email_ban) { FactoryBot.create(:email_ban, reason: :email_domain, end_at:) }
    let(:email_ban_duplicate) {}
    let(:user) { email_ban.user }
    let(:end_at) { nil }
    it "is valid" do
      expect(email_ban).to be_valid
      expect(user.reload.email_banned?).to be_truthy
      expect(email_ban.reason_humanized).to eq "domain"
      # It doesn't let the same thing be created for the same user
      expect(FactoryBot.build(:email_ban, user:, reason: :email_domain, start_at: Time.current - 1.hour))
        .to_not be_valid
      expect(FactoryBot.build(:email_ban, user:, reason: :email_duplicate)).to be_valid
    end
    context "end_at before now" do
      let(:end_at) { Time.current - 1.hour }
      it "is not email_banned" do
        expect(email_ban).to be_valid
        expect(user.reload.email_banned?).to be_falsey

        # It lets a new one be created because the old one isn't active
        expect(FactoryBot.build(:email_ban, user:, reason: :email_domain)).to_not be_valid
      end
    end
  end

  describe "ban?" do
    before { stub_const("EmailDomain::VERIFICATION_ENABLED", true) }
    let(:email) { "example@example.honeybadger.io" }
    let(:domain) { "@example.honeybadger.io" }
    let!(:user) { FactoryBot.create(:user, email:) }

    before do
      EmailDomain.invalid_domain_record # so it doesn't mess up the change counts later
      Sidekiq::Job.clear_all
    end

    it "processes email domain inline" do
      VCR.use_cassette("email_ban_process_email_domain") do
        expect do
          expect(EmailBan.ban?(user)).to be_falsey
        end.to change(EmailDomain, :count).by(1)
          .and change(EmailBan, :count).by(0)
        email_domain = EmailDomain.order(:id).last
        expect(email_domain.processed?).to be_truthy
        expect(UpdateEmailDomainJob.jobs.count).to eq 0
      end
    end

    context "invalid domain" do
      let(:email) { "dddd@ff=.com" }
      it "deletes user" do
        expect(EmailDomain.invalid_domain_record.banned?).to be_truthy
        expect do
          expect(EmailBan.ban?(user)).to be_truthy
        end.to change(EmailDomain, :count).by(0)
          .and change(User, :count).by(-1)
        expect(UpdateEmailDomainJob.jobs.count).to eq 0
      end
    end

    context "already existing email domain" do
      let!(:email_domain) do
        FactoryBot.create(:email_domain, domain:, user_count: 222, skip_processing: true, status:)
      end
      let(:email_domain_tld) { FactoryBot.create(:email_domain, domain: "honeybadger.io", skip_processing: true, status: tld_status) }
      let(:status) { "permitted" }

      it "enqueues processing of job" do
        expect(EmailDomain.find_or_create_for(user.email, skip_processing: true)).to eq email_domain
        expect(email_domain.reload.processed?).to be_truthy
        expect(email_domain.status).to eq status
        expect(email_domain.calculated_users.count).to_not eq email_domain.user_count # Verify it hasn't been processed

        expect do
          expect(EmailBan.ban?(user)).to be_falsey
        end.to change(EmailDomain, :count).by(0)
          .and change(EmailBan, :count).by(0)
        expect(email_domain.calculated_users.count).to_not eq email_domain.user_count # Verify it still hasn't been processed
        expect(UpdateEmailDomainJob.jobs.count).to eq 1
      end

      context "status: provisional_ban" do
        let(:status) { "provisional_ban" }
        it "creates a ban" do
          expect do
            expect(EmailBan.ban?(user)).to be_truthy
          end.to change(EmailDomain, :count).by(0)
            .and change(EmailBan, :count).by(1)
          expect(email_domain.calculated_users.count).to_not eq email_domain.user_count # Verify it still hasn't been processed
          expect(UpdateEmailDomainJob.jobs.count).to eq 1
        end

        context "with TLD" do
          let(:tld_status) { "permitted" }
          it "matches the actual domain, creates a ban" do
            expect(email_domain_tld.reload.tld_matches_subdomains?).to be_truthy
            expect(email_domain_tld.status).to eq tld_status
            email_domain.update(updated_at: Time.current)
            expect(email_domain.reload.tld).to eq email_domain_tld.domain
            expect(email_domain.status).to eq status
            expect(EmailDomain.find_or_create_for(user.email)&.id).to eq email_domain.id

            expect do
              expect(EmailBan.ban?(user)).to be_truthy
            end.to change(EmailDomain, :count).by(0)
              .and change(EmailBan, :count).by(1)
            expect(UpdateEmailDomainJob.jobs.count).to eq 1
          end
        end
      end

      context "with TLD with provisional_ban" do
        let(:tld_status) { "provisional_ban" }
        it "matches the tld domain, creates a ban" do
          expect(email_domain_tld.reload.tld_matches_subdomains?).to be_truthy
          expect(email_domain_tld.status).to eq tld_status
          email_domain.update(updated_at: Time.current)
          expect(email_domain.reload.tld).to eq email_domain_tld.domain
          expect(email_domain.status).to eq tld_status

          expect do
            expect(EmailBan.ban?(user)).to be_truthy
          end.to change(EmailDomain, :count).by(0)
            .and change(EmailBan, :count).by(1)
          expect(email_domain.calculated_users.count).to_not eq email_domain.user_count # Verify it still hasn't been processed
          expect(UpdateEmailDomainJob.jobs.count).to eq 1
        end
      end
    end
  end

  describe "email and email_domain" do
    let(:email_ban) { FactoryBot.create(:email_ban) }
    it "returns the user's email" do
      expect(email_ban.email).to eq email_ban.user.email
      expect(email_ban.email_domain&.id).to be_present
    end
  end
end
