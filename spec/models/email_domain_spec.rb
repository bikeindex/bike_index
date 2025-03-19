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

    context "busted gmail" do
      let!(:email_domain_tld) { FactoryBot.create(:email_domain, domain: "ail.com", ignored:) }
      let(:ignored) { false }
      it "creates and finds for busted gmail" do
        email_domain = EmailDomain.find_or_create_for("t.b.000.07@g.m.ail.com")
        expect(email_domain&.id).to eq email_domain_tld.id
      end
      context "with ail.com ignored" do
        let(:ignored) { true }
        it "creates for busted gmail" do
          expect(email_domain_tld.reload.active?).to be_falsey
          email_domain = EmailDomain.find_or_create_for("t.b.000.07@g.m.ail.com")
          expect(email_domain&.id).to_not eq email_domain_tld.id
          expect(email_domain.tld?).to be_falsey
          expect(email_domain).to have_attributes(domain: "@g.m.ail.com", status: "permitted")
          expect(EmailDomain.find_or_create_for("b00007@g.m.ail.com")&.id).to eq email_domain.id
        end
      end
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
        expect(email_domain_at.tld_matches_subdomains?).to be_falsey
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

        tld_matches_subdomains = EmailDomain.find_or_create_for("co.jp")
        expect(tld_matches_subdomains).to be_valid
        expect(tld_matches_subdomains.reload.domain).to eq "co.jp"
        expect(tld_matches_subdomains.tld?).to be_truthy
        expect(tld_matches_subdomains.tld_matches_subdomains?).to be_truthy
        expect(tld_matches_subdomains.tld).to eq "co.jp"
        expect(EmailDomain.find_or_create_for("something@hotmail.co.jp")&.id).to eq tld_matches_subdomains.id
      end
    end
  end
end
