# == Schema Information
#
# Table name: email_domains
#
#  id                :bigint           not null, primary key
#  data              :jsonb
#  deleted_at        :datetime
#  domain            :string
#  status            :integer          default("permitted")
#  status_changed_at :datetime
#  user_count        :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  creator_id        :bigint
#
# Indexes
#
#  index_email_domains_on_creator_id  (creator_id)
#
require "rails_helper"

RSpec.describe EmailDomain, type: :model do
  describe "Factory" do
    let(:email_domain) { FactoryBot.create(:email_domain) }
    it "is valid" do
      expect(email_domain).to be_valid
    end
  end

  describe "validate domain" do
    context "without ." do
      let(:email_domain) { FactoryBot.build(:email_domain, domain: "@somethingcom") }
      it "is invalid" do
        expect(email_domain).to_not be_valid
        expect(email_domain.errors.full_messages.join).to match(".")
      end
    end
  end

  describe "contained in another" do
    let(:email_domain) { FactoryBot.create(:email_domain, domain: "fetely.click") }
    let(:email_domain_at) { FactoryBot.build(:email_domain, domain: "@fetely.click") }

    it "is not valid" do
      expect(email_domain).to be_valid
      expect(email_domain_at).to_not be_valid
      expect(email_domain_at.errors.full_messages.join).to match("fetely.click")
    end

    context "when at domain exists" do
      it "doesn't block" do
        email_domain_at.save!
        expect(email_domain_at.reload).to be_valid

        expect(email_domain).to be_valid
      end
    end
  end

  describe "invalid_domain" do
    let(:email_domain) { EmailDomain.invalid_domain_record }
    it "returns expected things" do
      expect(email_domain.reload.banned?).to be_truthy
      expect(EmailDomain.invalid_domain?(email_domain.domain)).to be_truthy
      expect(EmailDomain.tld_for(email_domain.domain)).to eq EmailDomain::INVALID_DOMAIN
      expect(email_domain.tld?).to be_truthy
      expect(email_domain.tld_matches_subdomains?).to be_truthy
    end
  end

  describe "find_or_create_for" do
    it "creates and finds" do
      email_domain = EmailDomain.find_or_create_for("example@bikeindex.org")
      expect(email_domain).to have_attributes(domain: "@bikeindex.org", status: "permitted")
      expect(email_domain.tld?).to be_truthy
      expect(EmailDomain.find_or_create_for("something@bikeindex.org")&.id).to eq email_domain.id
      expect(EmailDomain.find_or_create_for("@bikeindex.org")&.id).to eq email_domain.id
      expect(EmailDomain.find_or_create_for("something@stuff.bikeindex.org")&.id).to_not eq email_domain.id
    end

    it "creates and finds without @" do
      email_domain = EmailDomain.find_or_create_for("bikeindex.org")
      expect(email_domain.tld?).to be_truthy
      expect(email_domain).to have_attributes(domain: "bikeindex.org", status: "permitted")
      expect(EmailDomain.find_or_create_for("something@bikeindex.org")&.id).to eq email_domain.id
      expect(EmailDomain.find_or_create_for("@bikeindex.org")&.id).to eq email_domain.id
      expect(EmailDomain.find_or_create_for("something@stuff.bikeindex.org")&.domain).to eq "@stuff.bikeindex.org"
    end

    context "busted gmail" do
      let!(:email_domain_tld) { FactoryBot.create(:email_domain, domain: "ail.com", status:) }
      let(:status) { :permitted }
      it "creates and finds for busted gmail" do
        email_domain = EmailDomain.find_or_create_for("t.b.000.07@g.m.ail.com")
        expect(email_domain&.domain).to eq "@g.m.ail.com"
        expect(email_domain.tld).to eq email_domain_tld.domain
      end
      context "with ail.com ignored" do
        let(:status) { :ignored }
        it "creates for busted gmail" do
          expect(email_domain_tld.reload.ignored?).to be_truthy
          email_domain = EmailDomain.find_or_create_for("t.b.000.07@g.m.ail.com")
          expect(email_domain&.id).to_not eq email_domain_tld.id
          expect(email_domain.tld?).to be_falsey
          expect(email_domain).to have_attributes(domain: "@g.m.ail.com", status: "permitted")
          expect(EmailDomain.find_or_create_for("b00007@g.m.ail.com")&.id).to eq email_domain.id
        end
      end
    end

    context "with invalid characters" do
      let(:invalid_domain) { EmailDomain.invalid_domain_record }
      let(:invalid_characters) { ["/", "\\", "(", ")", "[", "]", "=", " ", "!"] }
      it "returns invalid_domain" do
        invalid_characters.each do |char|
          expect(EmailDomain.find_or_create_for("@example#{char}.com")&.id).to eq invalid_domain.id
        end
      end
    end

    context "with subdomain" do
      let!(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "xxxx.stuff.com") }
      it "creates and finds" do
        expect(EmailDomain.tld_for("something@xxxx.stuff.com")).to eq "stuff.com"
        expect(EmailDomain.find_or_create_for("something@xxxx.stuff.com")&.id).to eq email_domain_sub.id
        expect(EmailDomain.find_or_create_for("xxxx.stuff.com")&.id).to eq email_domain_sub.id
        email_domain_fff = EmailDomain.find_or_create_for("fff.xxxx.stuff.com")
        expect(email_domain_fff.id).to_not eq email_domain_sub.id
        expect(EmailDomain.find_or_create_for("@fff.xxxx.stuff.com")&.id).to eq email_domain_fff.id

        EmailDomain.find_or_create_for("stuff.com")
        expect(EmailDomain.find_or_create_for("xxxx.stuff.com")&.id).to eq email_domain_sub.id
        expect(EmailDomain.find_or_create_for("something@xxxx.stuff.com")&.id).to eq email_domain_sub.id
      end
    end

    context "with broader domain with provisional_ban" do
      let(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "xxxx.stuff.com", status:, skip_processing: true) }
      let(:domain_sub_sub) { "zzzz.xxxx.stuff.com" }
      let(:status) { "provisional_ban" }
      it "sets to provisional_ban" do
        expect(email_domain_sub.reload.status).to eq status
        expect(email_domain_sub.tld).to eq "stuff.com"
        expect(EmailDomain.pluck(:domain, :status)).to eq([[email_domain_sub.domain, status]])

        expect(EmailDomain.broadest_matching_domains(domain_sub_sub).pluck(:id)).to eq([email_domain_sub.id])
        email_domain_sub_sub = EmailDomain.find_or_create_for(domain_sub_sub, skip_processing: true)
        expect(email_domain_sub_sub).to be_valid
        expect(email_domain_sub_sub.tld).to eq "stuff.com"
        expect(email_domain_sub_sub.status).to eq status
        expect(EmailDomain.broadest_matching_domains(domain_sub_sub).pluck(:id)).to match_array([email_domain_sub_sub.id, email_domain_sub.id])
      end
      context "with banned" do
        let(:status) { "banned" }
        it "sets to banned" do
          expect(email_domain_sub.reload.status).to eq status

          email_domain_sub_sub = EmailDomain.find_or_create_for(domain_sub_sub, skip_processing: true)
          expect(email_domain_sub_sub.tld).to eq "stuff.com"
          expect(email_domain_sub_sub.status).to eq status
        end
        context "with TLD provisionally banned" do
          let!(:email_domain) { FactoryBot.create(:email_domain, domain: "stuff.com", status: "provisional_ban", skip_processing: true) }
          it "sets to provisional_ban" do
            expect(email_domain_sub.reload.status).to eq status
            expect(email_domain.reload.status).to eq "provisional_ban"

            email_domain_sub_sub = EmailDomain.find_or_create_for(domain_sub_sub, skip_processing: true)
            expect(email_domain_sub_sub.status).to eq status
          end
        end
      end
      context "on update" do
        it "assigns to provisional_ban" do
          email_domain_sub_sub = EmailDomain.find_or_create_for(domain_sub_sub, skip_processing: true)
          expect(email_domain_sub_sub.status).to eq "permitted"

          expect(email_domain_sub.reload.status).to eq status

          email_domain_sub_sub.update(updated_at: Time.current)
          expect(email_domain_sub_sub.reload.status).to eq status
        end
        context "when email_domain has no_auto_assign_status" do
          it "does not assign to provisional_ban" do
            email_domain_sub_sub = EmailDomain.find_or_create_for(domain_sub_sub, skip_processing: true)
            email_domain_sub_sub.update(data: {no_auto_assign_status: true})
            expect(email_domain_sub_sub.no_auto_assign_status?).to be_truthy
            expect(email_domain_sub_sub.tld).to eq "stuff.com"
            expect(email_domain_sub_sub.status).to eq "permitted"

            expect(email_domain_sub.reload.status).to eq status

            email_domain_sub_sub.update(updated_at: Time.current)
            expect(email_domain_sub_sub.reload.status).to eq "permitted"
          end
        end
      end
      context "with TLD not banned" do
        let!(:email_domain) { FactoryBot.create(:email_domain, domain: "stuff.com", skip_processing: true) }
        it "sets to provisional_ban" do
          expect(email_domain_sub.reload.status).to eq status
          expect(email_domain_sub.reload.tld).to eq "stuff.com"
          expect(email_domain.reload.status).to eq "permitted"

          email_domain_sub_sub = EmailDomain.find_or_create_for(domain_sub_sub, skip_processing: true)
          expect(email_domain_sub_sub).to be_valid
          expect(email_domain_sub_sub.tld).to eq "stuff.com"
          expect(email_domain_sub_sub.status).to eq "provisional_ban" # status

          # Verify that email_domain doesn't get assigned subdomain's status
          email_domain.update(updated_at: Time.current)
          expect(email_domain.reload.status).to eq "permitted" # status
          expect(email_domain.ban_blockers).to eq(["below_email_count"])
        end
      end
    end

    context "with three subdomains" do
      let!(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "zzzz.hotmail.co.jp") }
      let!(:email_domain_at) { FactoryBot.create(:email_domain, domain: "@hotmail.co.jp") }
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "hotmail.co.jp") }
      it "finds" do
        expect(email_domain.reload.tld?).to be_truthy
        expect(email_domain_at.reload.tld?).to be_truthy
        expect(email_domain_at.tld_matches_subdomains?).to be_falsey
        expect(email_domain_sub.reload.tld?).to be_falsey
        expect(EmailDomain.find_or_create_for("something@hotmail.co.jp")&.id).to eq email_domain_at.id
        expect { EmailDomain.find_or_create_for("something@ffff.hotmail.co.jp")&.id }.to change(EmailDomain, :count).by 1

        weird_should_have_subdomain = EmailDomain.find_or_create_for("something@co.jp")
        expect(weird_should_have_subdomain).to be_valid
        expect(weird_should_have_subdomain.reload.domain).to eq "@co.jp"
        expect(weird_should_have_subdomain.tld?).to be_truthy
        expect(weird_should_have_subdomain.tld).to eq "co.jp"
        expect(EmailDomain.find_or_create_for("whatever@co.jp")&.id).to eq weird_should_have_subdomain.id
        expect(EmailDomain.find_or_create_for("something@hotmail.co.jp")&.id).to eq email_domain_at.id
      end
    end
  end

  describe "find_matching_domain" do
    let(:domain) { "@goose.rixyle.com" }
    let!(:email_domain) { EmailDomain.find_or_create_for(domain, skip_processing: true) }
    let(:tld) { "rixyle.com" }
    let!(:email_domain_tld) { EmailDomain.find_or_create_for(tld, skip_processing: true) }
    it "returns the closest" do
      EmailDomain.invalid_domain_record # so counts don't get messed up
      Sidekiq::Job.clear_all
      expect(email_domain_tld.reload.domain).to eq tld
      expect(email_domain.reload.tld).to eq tld
      VCR.use_cassette("email_domain-find_matching_with_tlds") do
        expect do
          UpdateEmailDomainJob.new.perform(email_domain.id)
          UpdateEmailDomainJob.new.perform(email_domain_tld.id)
        end.to change(EmailDomain, :count).by(0)
          .and change(UpdateEmailDomainJob.jobs, :count).by 0
      end

      expect(EmailDomain.find_matching_domain(tld)&.id).to eq email_domain_tld.id
      expect(EmailDomain.find_matching_domain(domain)&.id).to eq email_domain.id
    end
  end

  describe "should_re_process?" do
    let(:email_domain) { EmailDomain.new }
    it "is truthy" do
      expect(email_domain.should_re_process?).to be_truthy
    end
    context "with over 10 bikes" do
      let(:spam_score) { 2 }
      let(:updated_at) { Time.current - 1.day }
      let(:email_domain) do
        FactoryBot.build(:email_domain, updated_at:, data: {bike_count: 10, spam_score:, notification_count: 20}.as_json)
      end
      it "is falsey" do
        expect(email_domain.should_re_process?).to be_truthy
      end
      context "updated_at > 1.hour ago" do
        let(:updated_at) { Time.current - 20.minutes }
        it "is falsey, unless notification_count < 20" do
          expect(email_domain.should_re_process?).to be_falsey
          email_domain.data["notification_count"] = 19
          expect(email_domain.should_re_process?).to be_truthy
        end
        context "spam_score 4" do
          let(:spam_score) { 4 }
          it "is truthy" do
            expect(email_domain.should_re_process?).to be_truthy
          end
        end
      end
      context "updated before RE_PROCESS_DELAY" do
        let(:updated_at) { Time.current - 1.year }
        it "is truthy if spam score is below 3" do
          expect(email_domain.should_re_process?).to be_truthy
        end
      end
    end
  end
end
