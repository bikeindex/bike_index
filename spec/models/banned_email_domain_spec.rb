require "rails_helper"

RSpec.describe BannedEmailDomain, type: :model do
  describe "Factory" do
    let(:banned_email_domain) { FactoryBot.create(:banned_email_domain) }
    it "is valid" do
      expect(banned_email_domain).to be_valid
    end
  end

  describe "validate domain" do
    context "without ." do
      let(:banned_email_domain) { FactoryBot.build(:banned_email_domain, domain: "@somethingcom") }
      it "is invalid" do
        expect(banned_email_domain).to_not be_valid
        expect(banned_email_domain.errors.full_messages.join).to match(".")
      end
    end
  end

  describe "contained in another" do
    let(:banned_email_domain) { FactoryBot.create(:banned_email_domain, domain: "fetely.click") }
    let(:banned_email_domain_extended) { FactoryBot.build(:banned_email_domain, domain: "@fetely.click") }

    it "is not valid" do
      expect(banned_email_domain).to be_valid
      expect(banned_email_domain_extended).to_not be_valid
      expect(banned_email_domain_extended.errors.full_messages.join).to match("fetely.click")
    end

    context "when larger string exists" do
      it "doesn't block" do
        banned_email_domain_extended.save!
        expect(banned_email_domain_extended.reload).to be_valid

        expect(banned_email_domain).to be_valid
      end
    end
  end

  describe "allow_creation?" do
    it "is truthy for incorrect format" do
      # These can just be handled by the domain_is_expected_format validation
      expect(BannedEmailDomain.allow_creation?("@somethingcom")).to be_truthy
    end
  end

  describe "allow_creation?" do
    it "is falsey for domain when nothing matches" do
      expect(BannedEmailDomain.allow_creation?("@something.com")).to be_falsey
    end

    context "with email over EMAIL_MIN_COUNT" do
      let(:domain) { "@something.com" }
      let!(:user) { FactoryBot.create(:user_confirmed, email: "fff#{domain}") }

      before { stub_const("BannedEmailDomain::EMAIL_MIN_COUNT", 0) }

      it "is truthy" do
        expect(BannedEmailDomain.too_few_emails?(domain)).to be_falsey
        expect(BannedEmailDomain.too_many_bikes?(domain)).to be_falsey
        expect(BannedEmailDomain.no_valid_organization_roles?(domain)).to be_truthy
        expect(BannedEmailDomain.allow_creation?(domain)).to be_truthy
      end

      context "3 bikes in domain" do
        let!(:bike1) { FactoryBot.create(:bike, owner_email: "fff#{domain}") }
        let!(:bike2) { FactoryBot.create(:bike, owner_email: "ffg#{domain}") }
        let!(:bike3) { FactoryBot.create(:bike, owner_email: "ffh#{domain}") }
        it "is falsey" do
          expect(BannedEmailDomain.allow_creation?(domain)).to be_falsey
        end
      end

      context "with a membership in the domain" do
        let(:organization) { FactoryBot.create(:organization, approved: true) }
        let!(:organization_user) { FactoryBot.create(:organization_user, organization:, user:) }
        it "is falsey" do
          expect(BannedEmailDomain.allow_creation?(domain)).to be_falsey
        end

        context "with organization unapproved" do
          before { organization.update(approved: false) }

          it "is truthy" do
            expect(OrganizationRole.count).to eq 1
            expect(BannedEmailDomain.too_few_emails?(domain)).to be_falsey
            expect(BannedEmailDomain.too_many_bikes?(domain)).to be_falsey
            expect(BannedEmailDomain.no_valid_organization_roles?(domain)).to be_truthy
            expect(BannedEmailDomain.allow_creation?(domain)).to be_truthy
          end
        end
      end
    end
  end
end
