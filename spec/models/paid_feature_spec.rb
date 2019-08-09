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
    let(:organization) { FactoryBot.create(:organization_with_paid_features, kind: "law_enforcement", paid_feature_slugs: ["bike_codes"]) }
    let(:invoice) { organization.current_invoices.first }
    let(:organization_child) { FactoryBot.create(:organization_with_paid_features, parent_organization: organization, kind: "bike_shop", paid_feature_slugs: "bike_search") }
    context "without child_paid_feature_slugs" do
      it "does not inherit from the parent" do
        expect(invoice.child_paid_feature_slugs).to eq([])
        expect(organization_child.current_invoices.pluck(:id)).to match_array([organization_child.invoices.first.id])
        organization.update_attributes(updated_at: Time.current) # TODO: Rails 5 update - after commit doesn't run - for parent org update
        expect(organization.kind).to eq "law_enforcement"
        expect(organization_child.kind).to eq "bike_shop"
        expect(organization.paid_feature_slugs).to eq %w[bike_codes]
        expect(organization.child_ids).to eq([organization_child.id])
        expect(organization_child.paid_feature_slugs).to eq %w[bike_search]
        # Just to make sure it doesn't get child_organizations # TODO: Rails 5 update - after_commit
        organization_child.update_attributes(updated_at: Time.current)
        organization_child.reload
        expect(organization_child.paid_feature_slugs).to eq %w[bike_search]
      end
    end
    context "with child_paid_feature_slugs" do
      it "inherits from the parent organization, not other way around" do
        invoice.update_attributes(child_paid_feature_slugs_string: "bike_codes")
        expect(organization.paid_feature_slugs).to eq(["bike_codes"])
        expect(organization_child.current_invoices.pluck(:id)).to match_array([organization_child.invoices.first.id])
        organization.update_attributes(updated_at: Time.current) # TODO: Rails 5 update - after commit doesn't run - for parent org update
        expect(organization.kind).to eq "law_enforcement"
        expect(organization_child.kind).to eq "bike_shop"
        expect(organization.paid_feature_slugs).to eq %w[bike_codes]
        expect(organization.child_ids).to eq([organization_child.id])
        expect(organization_child.paid_feature_slugs).to eq %w[bike_codes bike_search]
        # Just to make sure it doesn't get child_organizations # TODO: Rails 5 update - after_commit
        organization_child.update_attributes(updated_at: Time.current)
        organization_child.reload
        expect(organization_child.paid_feature_slugs).to match_array(%w[bike_codes bike_search])
      end
    end
  end
end
