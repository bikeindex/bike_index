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
    let(:email_domain_extended) { FactoryBot.build(:email_domain, domain: "@fetely.click") }

    it "is not valid" do
      expect(email_domain).to be_valid
      expect(email_domain_extended).to_not be_valid
      expect(email_domain_extended.errors.full_messages.join).to match("fetely.click")
    end

    context "when larger string exists" do
      it "doesn't block" do
        email_domain_extended.save!
        expect(email_domain_extended.reload).to be_valid

        expect(email_domain).to be_valid
      end
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
      expect(EmailDomain.find_or_create_for("something@stuff.bikeindex.org")&.id).to eq email_domain.id
    end

    context "with subdomain" do
      let!(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "xxxx.stuff.com") }
      it "creates and finds" do
        expect(EmailDomain.tld_for("something@xxxx.stuff.com")).to eq "stuff.com"
        expect(EmailDomain.find_or_create_for("something@xxxx.stuff.com")&.id).to eq email_domain_sub.id
        expect(EmailDomain.find_or_create_for("xxxx.stuff.com")&.id).to eq email_domain_sub.id
        expect(EmailDomain.find_or_create_for("fff.xxxx.stuff.com")&.id).to eq email_domain_sub.id
        email_domain_fff = EmailDomain.find_or_create_for("@fff.stuff.com")
        expect(email_domain_fff.id).to_not eq email_domain_sub.id
        expect(EmailDomain.find_or_create_for("@fff.xxxx.stuff.com")&.id).to eq email_domain_sub.id
        expect(EmailDomain.find_or_create_for("fff.stuff.com")&.id).to eq email_domain_fff.id

        email_domain = EmailDomain.find_or_create_for("stuff.com")
        expect(EmailDomain.find_or_create_for("xxxx.stuff.com")&.id).to eq email_domain.id
        expect(EmailDomain.send(:matching_domain, "xxx.stuff.com").pluck(:id)).to eq([email_domain_sub.id])
        expect(EmailDomain.find_or_create_for("something@xxxx.stuff.com")&.id).to eq email_domain.id
      end
    end

    context "with tld" do
      let!(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "xxxx.stuff.com") }
      let!(:email_domain_at) { FactoryBot.create(:email_domain, domain: "@stuff.com") }
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "stuff.com") }
      it "finds" do
        expect(email_domain_sub.reload.tld).to eq "stuff.com"
        expect(email_domain.reload.tld?).to be_truthy
        expect(email_domain_at.reload.tld?).to be_truthy
        expect(EmailDomain.send(:matching_domain, "stuff.com").map(&:id)).to eq([email_domain.id, email_domain_at.id, email_domain_sub.id])
        expect(EmailDomain.find_or_create_for("something@stuff.stuff.com")&.id).to eq email_domain.id
      end
    end

    context "with three subdomains" do
      let!(:email_domain_sub) { FactoryBot.create(:email_domain, domain: "zzzz.hotmail.co.jp") }
      let!(:email_domain_at) { FactoryBot.create(:email_domain, domain: "@hotmail.co.jp") }
      let!(:email_domain) { FactoryBot.create(:email_domain, domain: "hotmail.co.jp") }
      it "finds" do
        expect(email_domain.reload.tld?).to be_truthy
        expect(email_domain_at.reload.tld?).to be_truthy
        expect(email_domain_sub.reload.tld?).to be_falsey
        expect(EmailDomain.find_or_create_for("something@ffff.hotmail.co.jp")&.id).to eq email_domain.id
        expect(EmailDomain.find_or_create_for("something@hotmail.co.jp")&.id).to eq email_domain.id

        weird_should_have_subdomain = EmailDomain.find_or_create_for("something@co.jp")
        expect(weird_should_have_subdomain).to be_valid
        expect(weird_should_have_subdomain.reload.domain).to eq "@co.jp"
        expect(weird_should_have_subdomain.tld?).to be_truthy
        expect(weird_should_have_subdomain.tld).to eq "co.jp"
        expect(EmailDomain.find_or_create_for("whatever@co.jp")&.id).to eq weird_should_have_subdomain.id
        expect(EmailDomain.find_or_create_for("something@hotmail.co.jp")&.id).to eq email_domain.id

        # TODO: Make this work right:
        # even_more_tld = EmailDomain.find_or_create_for("co.jp")
        # expect(even_more_tld).to be_valid
        # expect(even_more_tld.reload.domain).to eq "co.jp"
        # expect(even_more_tld.tld?).to be_truthy
        # expect(even_more_tld.tld).to eq "co.jp"
        # expect(EmailDomain.find_or_create_for("something@hotmail.co.jp")&.id).to eq even_more_tld.id
      end
    end
  end

  describe "allow_domain_ban?" do
    it "is truthy for incorrect format" do
      # These can just be handled by the domain_is_expected_format validation
      expect(EmailDomain.allow_domain_ban?("@somethingcom")).to be_truthy
    end
  end

  describe "allow_domain_ban?" do
    it "is falsey for domain when nothing matches" do
      expect(EmailDomain.allow_domain_ban?("@something.com")).to be_falsey
    end

    context "with email over EMAIL_MIN_COUNT" do
      let(:domain) { "@something.com" }
      let!(:user) { FactoryBot.create(:user_confirmed, email: "fff#{domain}") }

      before { stub_const("EmailDomain::EMAIL_MIN_COUNT", 0) }

      it "is truthy" do
        expect(EmailDomain.too_few_emails?(domain)).to be_falsey
        expect(EmailDomain.too_many_bikes?(domain)).to be_falsey
        expect(EmailDomain.no_valid_organization_roles?(domain)).to be_truthy
        expect(EmailDomain.allow_domain_ban?(domain)).to be_truthy
      end

      context "3 bikes in domain" do
        let!(:bike1) { FactoryBot.create(:bike, owner_email: "fff#{domain}") }
        let!(:bike2) { FactoryBot.create(:bike, owner_email: "ffg#{domain}") }
        let!(:bike3) { FactoryBot.create(:bike, owner_email: "ffh#{domain}") }
        it "is falsey" do
          expect(EmailDomain.allow_domain_ban?(domain)).to be_falsey
        end
      end

      context "with a organization_role in the domain" do
        let(:organization) { FactoryBot.create(:organization, approved: true) }
        let!(:organization_role) { FactoryBot.create(:organization_role, organization:, user:) }
        it "is falsey" do
          expect(EmailDomain.allow_domain_ban?(domain)).to be_falsey
        end

        context "with organization unapproved" do
          before { organization.update(approved: false) }

          it "is truthy" do
            expect(OrganizationRole.count).to eq 1
            expect(EmailDomain.too_few_emails?(domain)).to be_falsey
            expect(EmailDomain.too_many_bikes?(domain)).to be_falsey
            expect(EmailDomain.no_valid_organization_roles?(domain)).to be_truthy
            expect(EmailDomain.allow_domain_ban?(domain)).to be_truthy
          end
        end
      end
    end
  end
end
