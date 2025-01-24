require 'rails_helper'

RSpec.describe BannedEmailDomain, type: :model do
  describe "Factory" do
    let(:banned_email_domain) { FactoryBot.create(:banned_email_domain) }
    it "is valid" do
      expect(banned_email_domain).to be_valid
    end
  end

  describe "validate domain" do
    context "without @" do
      let(:banned_email_domain) { FactoryBot.build(:banned_email_domain, domain: "something.com") }
      it "is invalid" do
        expect(banned_email_domain).to_not be_valid
        expect(banned_email_domain.errors.full_messages.join).to match("@")
      end
    end
    context "without ." do
      let(:banned_email_domain) { FactoryBot.build(:banned_email_domain, domain: "@somethingcom") }
      it "is invalid" do
        expect(banned_email_domain).to_not be_valid
        expect(banned_email_domain.errors.full_messages.join).to match(".")
      end
    end
  end
end
