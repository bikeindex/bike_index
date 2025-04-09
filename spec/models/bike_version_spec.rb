require "rails_helper"

RSpec.describe BikeVersion, type: :model do
  it_behaves_like "bike_attributable"

  describe "factory" do
    let(:bike_version) { FactoryBot.create(:bike_version) }
    it "is valid" do
      expect(bike_version).to be_valid
      expect(bike_version.bike).to be_present
      expect(bike_version.owner).to eq bike_version.bike.owner
    end
  end

  describe "authorized? and visible_by?" do
    let(:bike_version) { FactoryBot.create(:bike_version) }
    let(:owner) { bike_version.owner }
    let(:user) { FactoryBot.create(:user) }
    let(:superuser) { FactoryBot.create(:superuser) }
    it "is false for non-owner" do
      expect(bike_version.authorized?(nil)).to be_falsey
      expect(bike_version.authorized?(user)).to be_falsey
      expect(bike_version.authorized?(owner)).to be_truthy
      expect(bike_version.authorized?(owner, no_superuser_override: true)).to be_truthy
      expect(bike_version.authorized?(superuser)).to be_truthy
      expect(bike_version.authorized?(superuser, no_superuser_override: true)).to be_falsey
      # visible
      expect(bike_version.visible_by?).to be_truthy
      expect(bike_version.visible_by?(user)).to be_truthy
      expect(bike_version.visible_by?(owner)).to be_truthy
      expect(bike_version.visible_by?(superuser)).to be_truthy
      # And off of user
      expect(user.authorized?(bike_version)).to be_falsey
      expect(owner.authorized?(bike_version)).to be_truthy
      expect(owner.authorized?(bike_version, no_superuser_override: true)).to be_truthy
      expect(superuser.authorized?(bike_version)).to be_truthy
      expect(superuser.authorized?(bike_version, no_superuser_override: true)).to be_falsey
    end
    context "user_hidden" do
      let(:bike_version) { FactoryBot.create(:bike_version, visibility: "user_hidden") }
      it "is as expected" do
        expect(bike_version.authorized?(nil)).to be_falsey
        expect(bike_version.authorized?(user)).to be_falsey
        expect(bike_version.authorized?(owner)).to be_truthy
        expect(bike_version.authorized?(owner, no_superuser_override: true)).to be_truthy
        expect(bike_version.authorized?(superuser)).to be_truthy
        expect(bike_version.authorized?(superuser, no_superuser_override: true)).to be_falsey
        # visible
        expect(bike_version.visible_by?).to be_falsey
        expect(bike_version.visible_by?(user)).to be_falsey
        expect(bike_version.visible_by?(owner)).to be_truthy
        expect(bike_version.visible_by?(superuser)).to be_truthy
      end
    end
  end

  describe "cached_data" do
    let(:bike_version) { FactoryBot.create(:bike_version) }
    it "caches" do
      expect(bike_version.reload.cached_data).to be_present
    end
  end
end
