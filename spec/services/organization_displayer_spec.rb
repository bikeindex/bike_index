require "rails_helper"

RSpec.describe OrganizationDisplayer do
  describe "law_enforcement_missing_verified_features?" do
    let(:law_enforcement_organization) { Organization.new(kind: "law_enforcement") }
    let(:law_enforcement_organization_with_unstolen) { Organization.new(kind: "law_enforcement", enabled_feature_slugs: ["unstolen_notifications"]) }
    let(:bike_shop_organization) { Organization.new(kind: "bike_shop") }
    it "is true for law_enforcement, false for shop, false for law_enforcement with unstolen_notifications" do
      expect(OrganizationDisplayer.law_enforcement_missing_verified_features?(law_enforcement_organization)).to be_truthy
      expect(OrganizationDisplayer.law_enforcement_missing_verified_features?(bike_shop_organization)).to be_falsey
      expect(OrganizationDisplayer.law_enforcement_missing_verified_features?(law_enforcement_organization_with_unstolen)).to be_falsey
    end
  end

  describe "avatar?" do
    let(:organization) { Organization.new }
    before { allow(organization).to receive(:avatar) { "a pretty picture" } }
    it "displays" do
      expect(OrganizationDisplayer.avatar?(organization)).to be_truthy
    end
    # someday, we might only want to show it for paid organizations
    context "paid" do
      it "displays" do
        organization.is_paid = true
        expect(OrganizationDisplayer.avatar?(organization)).to be_truthy
      end
    end
  end

  describe "bike_shop_display_integration_alert?" do
    let(:organization) { Organization.new(kind: "law_enforcement", pos_kind: "no_pos") }
    it "is falsey for non-shops" do
      expect(OrganizationDisplayer.bike_shop_display_integration_alert?(organization)).to be_falsey
    end
    context "shop" do
      let(:organization) { Organization.new(kind: "bike_shop", pos_kind: pos_kind) }
      let(:pos_kind) { "no_pos" }
      it "is true" do
        expect(OrganizationDisplayer.bike_shop_display_integration_alert?(organization)).to be_truthy
      end
      context "lightspeed_pos" do
        let(:pos_kind) { "lightspeed_pos" }
        it "is false" do
          expect(OrganizationDisplayer.bike_shop_display_integration_alert?(organization)).to be_falsey
        end
      end
      context "ascend_pos" do
        let(:pos_kind) { "ascend_pos" }
        it "is false" do
          expect(OrganizationDisplayer.bike_shop_display_integration_alert?(organization)).to be_falsey
        end
      end
      context "broken_pos" do
        let(:pos_kind) { "broken_lightspeed_pos" }
        it "is true" do
          expect(OrganizationDisplayer.bike_shop_display_integration_alert?(organization)).to be_truthy
        end
      end
      context "does_not_need_pos" do
        let(:pos_kind) { "does_not_need_pos" }
        it "is falsey" do
          expect(OrganizationDisplayer.bike_shop_display_integration_alert?(organization)).to be_falsey
        end
      end
    end
  end
end
