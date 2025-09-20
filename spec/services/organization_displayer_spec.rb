require "rails_helper"

RSpec.describe OrganizationDisplayer do
  describe "law_enforcement_missing_verified_features?" do
    let(:law_enforcement_organization) { Organization.new(kind: "law_enforcement") }
    let(:bike_shop_organization) { Organization.new(kind: "bike_shop") }
    it "is true for law_enforcement, false for shop, false for law_enforcement with unstolen_notifications" do
      expect(OrganizationDisplayer.law_enforcement_missing_verified_features?(law_enforcement_organization)).to be_truthy
      expect(OrganizationDisplayer.law_enforcement_missing_verified_features?(bike_shop_organization)).to be_falsey
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

  describe "subscription_expired_alert?" do
    let(:organization) { Organization.new }
    it "is falsey" do
      expect(OrganizationDisplayer.subscription_expired_alert?(organization)).to be_falsey
      organization.is_paid = true
      expect(OrganizationDisplayer.subscription_expired_alert?(organization)).to be_falsey
    end
    context "with current invoice" do
      let(:invoice) { FactoryBot.create(:invoice_with_payment, start_at: 1.year.ago, end_at: end_at) }
      let!(:organization) { invoice.organization }
      let(:end_at) { 1.week.from_now }
      let(:invoice2) { FactoryBot.create(:invoice_paid, organization: organization) }
      it "is falsey" do
        expect(OrganizationDisplayer.subscription_expired_alert?(organization)).to be_falsey
        # With an active free invoice, the result is the same
        expect(invoice2.reload.active?).to be_truthy
        expect(invoice2.paid_money_in_full?).to be_falsey
        expect(OrganizationDisplayer.subscription_expired_alert?(organization.reload)).to be_falsey
      end
      context "expired last week" do
        let(:end_at) { 1.week.ago }
        it "is truthy" do
          expect(OrganizationDisplayer.subscription_expired_alert?(organization)).to be_truthy
          # With an active free invoice, the result is the same
          expect(invoice2.reload.active?).to be_truthy
          expect(invoice2.paid_money_in_full?).to be_falsey
          expect(OrganizationDisplayer.subscription_expired_alert?(organization.reload)).to be_truthy
        end
      end
      context "expired last year" do
        let(:end_at) { 1.year.ago }
        it "is falsey" do
          expect(OrganizationDisplayer.subscription_expired_alert?(organization)).to be_falsey
        end
      end
    end
  end
end
