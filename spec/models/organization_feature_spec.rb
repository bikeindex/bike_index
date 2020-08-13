require "rails_helper"

RSpec.describe OrganizationFeature, type: :model do
  it_behaves_like "amountable"

  describe "feature_slugs_string" do
    let(:organization_feature) { OrganizationFeature.new }
    it "updates only including the expected ones" do
      organization_feature.feature_slugs_string = "REG_Phone,, PARKING_NOTIFICATIONs, Stuff"
      expect(organization_feature.feature_slugs).to eq(%w[reg_phone parking_notifications])
      organization_feature.feature_slugs_string = " \n"
      expect(organization_feature.feature_slugs).to eq([])
    end
  end

  describe "child organization" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, kind: "law_enforcement", enabled_feature_slugs: %w[child_organizations bike_stickers]) }
    let(:invoice) { organization.current_invoices.first }
    let(:organization_child) { FactoryBot.create(:organization_with_organization_features, parent_organization: organization, kind: "bike_shop", enabled_feature_slugs: "bike_search") }
    context "without child_enabled_feature_slugs" do
      it "does not inherit from the parent" do
        Sidekiq::Testing.inline! do
          expect(invoice.child_enabled_feature_slugs).to eq([])
          expect(organization_child.current_invoices.pluck(:id)).to match_array([organization_child.invoices.first.id])

          expect(organization.kind).to eq "law_enforcement"
          expect(organization_child.kind).to eq "bike_shop"
          expect(organization.enabled_feature_slugs).to eq %w[child_organizations bike_stickers]
          expect(organization.reload.child_ids).to eq([organization_child.id])
          expect(organization_child.enabled_feature_slugs).to eq %w[bike_search]
        end
      end
    end
    context "with child_enabled_feature_slugs" do
      it "inherits from the parent organization, not other way around" do
        Sidekiq::Testing.inline! do
          invoice.update_attributes(child_enabled_feature_slugs_string: "bike_stickers")

          expect(organization.enabled_feature_slugs).to eq(%w[child_organizations bike_stickers])
          expect(organization_child.current_invoices.pluck(:id)).to match_array([organization_child.invoices.first.id])
          expect(organization.kind).to eq "law_enforcement"
          expect(organization_child.kind).to eq "bike_shop"
          expect(organization.enabled_feature_slugs).to eq %w[child_organizations bike_stickers]

          expect(organization.reload.child_ids).to eq([organization_child.id])
          expect(organization_child.enabled_feature_slugs).to match_array(%w[bike_stickers bike_search])
        end
      end
    end
  end

  describe "additional_reg_field_bike_attrs" do
    let(:bike) { Bike.new }
    let(:additional_reg_fields) { %w[organization_affiliation extra_registration_number reg_phone reg_address] }

    it "maps REG_FIELDS to bike attrs" do
      expect(additional_reg_fields).to match_array OrganizationFeature::REG_FIELDS
      additional_reg_fields.each do |reg_field|
        bike_attr = OrganizationFeature.reg_field_bike_attrs[reg_field.to_sym]
        expect(bike.send(bike_attr)).to be_blank
      end
    end
  end
end
