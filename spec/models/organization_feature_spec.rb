require "rails_helper"

RSpec.describe OrganizationFeature, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"

  describe "constant ordering" do
    it "is ordered" do
      expect(OrganizationFeature::REG_FIELDS.sort).to eq OrganizationFeature::REG_FIELDS
      expect(OrganizationFeature::BIKE_ACTIONS.sort).to eq OrganizationFeature::BIKE_ACTIONS
      expected_slugs = OrganizationFeature::EXPECTED_SLUGS - OrganizationFeature::REG_FIELDS - OrganizationFeature::BIKE_ACTIONS
      expect(expected_slugs.sort).to eq expected_slugs
    end
  end

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
    let!(:organization_child) { FactoryBot.create(:organization_with_organization_features, parent_organization: organization, kind: "bike_shop", enabled_feature_slugs: "bike_search") }
    context "without child_enabled_feature_slugs" do
      it "does not inherit from the parent" do
        Sidekiq::Testing.inline! do
          expect(invoice.child_enabled_feature_slugs).to eq([])
          expect(organization_child.current_invoices.pluck(:id)).to match_array([organization_child.invoices.first.id])

          expect(organization.kind).to eq "law_enforcement"
          expect(organization_child.kind).to eq "bike_shop"
          expect(organization.enabled_feature_slugs).to eq %w[bike_stickers child_organizations reg_bike_sticker]
          expect(organization.reload.child_ids).to eq([organization_child.id])
          expect(organization_child.enabled_feature_slugs).to eq %w[bike_search]
        end
      end
    end
    context "with child_enabled_feature_slugs" do
      it "inherits from the parent organization, not other way around" do
        Sidekiq::Testing.inline! do
          invoice.update(child_enabled_feature_slugs_string: "bike_stickers")

          expect(organization.enabled_feature_slugs).to eq(%w[bike_stickers child_organizations reg_bike_sticker])
          expect(organization_child.current_invoices.pluck(:id)).to match_array([organization_child.invoices.first.id])
          expect(organization.kind).to eq "law_enforcement"
          expect(organization_child.kind).to eq "bike_shop"
          expect(organization.enabled_feature_slugs).to eq %w[bike_stickers child_organizations reg_bike_sticker]

          expect(organization.reload.child_ids).to eq([organization_child.id])
          expect(organization_child.reload.enabled_feature_slugs).to match_array(%w[bike_search bike_stickers reg_bike_sticker])
        end
      end
    end
  end

  describe "reg_field_to_bike_attrs" do
    let(:bike) { Bike.new }
    let(:additional_reg_fields) { %w[reg_organization_affiliation reg_extra_registration_number reg_phone reg_address reg_bike_sticker reg_student_id] }

    it "maps REG_FIELDS to bike attrs" do
      expect(additional_reg_fields).to match_array OrganizationFeature::REG_FIELDS
      additional_reg_fields.each do |reg_field|
        bike_attr = OrganizationFeature.reg_field_to_bike_attrs(reg_field.to_sym)
        if bike_attr == "bike_sticker" # Because it accepts arguments, I guess? it fails
          expect(bike.bike_sticker).to be_blank
        else
          expect(bike.send(bike_attr)).to be_blank
        end
      end
    end
  end

  describe "reg_fields_with_customizable_labels" do
    let(:organization) { FactoryBot.build(:organization) }
    it "includes expected" do
      labeled_fields = OrganizationFeature.reg_fields_with_customizable_labels
      expect(labeled_fields.count).to eq OrganizationFeature::REG_FIELDS.count
      expect(labeled_fields).to include("owner_email")
      expect(labeled_fields).to_not include("reg_bike_sticker")
    end
  end

  describe "with_admin_organization_attributes" do
    let(:target_kinds) do
      %w[regional_bike_counts passwordless_users graduated_notifications
        organization_stolen_message reg_extra_registration_number
        reg_organization_affiliation reg_address reg_phone reg_student_id owner_email]
    end
    it "is expected" do
      expect(OrganizationFeature.with_admin_organization_attributes).to match_array target_kinds
    end
  end
end
