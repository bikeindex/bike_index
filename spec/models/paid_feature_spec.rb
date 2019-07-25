require "rails_helper"

RSpec.describe PaidFeature, type: :model do
  it_behaves_like "amountable"

  describe "feature_slugs_string" do
    let(:paid_feature) { PaidFeature.new }
    it "updates only including the expected ones" do
      paid_feature.feature_slugs_string = "messAGES, GEOLOCATED_MESSAGES, Stuff"
      expect(paid_feature.feature_slugs).to eq(%w[messages geolocated_messages])
      paid_feature.feature_slugs_string = " \n"
      expect(paid_feature.feature_slugs).to eq([])
    end
  end

  describe "child organization" do
    let(:paid_feature) { FactoryBot.create(:paid_feature, amount_cents: 10_000, feature_slugs: ["bike_codes"]) }
    let(:paid_feature2) { FactoryBot.create(:paid_feature, feature_slugs: ["bike_search"] ) }
    let!(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization) }
    let!(:invoice2) { FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization_child) }
    let(:organization) { FactoryBot.create(:organization, kind: "law_enforcement") }
    let(:organization_child) { FactoryBot.create(:organization, parent_organization: organization, kind: "bike_shop") }
    let(:target_paid_feature_slugs) { ["bike_codes"] }
    it "inherits from the parent organization, not other way around" do
      invoice.update_attributes(paid_feature_ids: [paid_feature.id])
      invoice2.update_attributes(paid_feature_ids: [paid_feature2.id])
      organization.update_attributes(updated_at: Time.current)
      organization_child.update_attributes(updated_at: Time.current)
      organization.reload
      organization_child.reload
      expect(organization.kind).to eq "law_enforcement"
      expect(organization_child.kind).to eq "bike_shop"
      expect(organization.paid_feature_slugs).to eq %w[bike_codes]
      expect(organization_child.paid_feature_slugs).to eq %w[bike_codes bike_search]
    end
  end
end
