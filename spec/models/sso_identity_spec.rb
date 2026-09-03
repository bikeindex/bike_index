require "rails_helper"

RSpec.describe SsoIdentity, type: :model do
  describe "factory" do
    let(:sso_identity) { FactoryBot.create(:sso_identity) }
    it "is valid" do
      expect(sso_identity).to be_valid
      expect(sso_identity.user).to be_present
      expect(sso_identity.organization).to be_present
    end
  end

  describe "validations" do
    it "requires provider and uid" do
      sso_identity = SsoIdentity.new
      expect(sso_identity).to_not be_valid
      expect(sso_identity.errors.attribute_names).to include(:provider, :uid)
    end

    context "uniqueness of uid scoped to organization + provider" do
      let!(:existing) { FactoryBot.create(:sso_identity, provider: "saml", uid: "shared-uid") }
      it "blocks a duplicate for the same org + provider" do
        duplicate = FactoryBot.build(:sso_identity, organization: existing.organization, provider: "saml", uid: "shared-uid")
        expect(duplicate).to_not be_valid
        expect(duplicate.errors.attribute_names).to include(:uid)
      end

      it "allows the same uid for a different organization" do
        other = FactoryBot.build(:sso_identity, provider: "saml", uid: "shared-uid")
        expect(other).to be_valid
      end
    end
  end

  describe ".for" do
    let!(:sso_identity) { FactoryBot.create(:sso_identity, provider: "saml", uid: "lookup-uid") }
    it "finds by organization, provider, uid" do
      expect(SsoIdentity.for(organization: sso_identity.organization, provider: "saml", uid: "lookup-uid")).to eq sso_identity
      expect(SsoIdentity.for(organization: sso_identity.organization, provider: "saml", uid: "nope")).to be_nil
    end
  end
end
