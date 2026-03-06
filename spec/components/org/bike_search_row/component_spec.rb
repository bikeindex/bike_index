# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeSearchRow::Component, type: :component do
  # rendered_content preserves raw HTML (including <td> elements that
  # Nokogiri would strip without a <table> wrapper)
  let(:html) do
    with_request_url("/o/#{organization.to_param}/bikes") do
      render_inline(described_class.new(**options))
    end
    rendered_content
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
  let(:options) { {bike:, organization:} }

  it "renders bike details" do
    expect(html).to include(bike.owner_email)
    expect(html).to include(bike.mnfg_name)
    expect(html).to include("url_cell")
    expect(html).to include("created_at_cell")
    expect(html).to include("manufacturer_cell")
    expect(html).to include("owner_email_cell")
  end

  context "with stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike, creation_organization: organization) }

    it "renders check mark in stolen cell" do
      expect(html).to include("stolen_cell")
      expect(html).to include("&#x2713;")
    end
  end

  context "with non-stolen bike" do
    it "does not render check mark in stolen cell" do
      expect(bike.status_stolen?).to be_falsey
      expect(html).to include("stolen_cell")
      expect(html).not_to include("✓")
    end
  end

  context "when email is hidden from organization" do
    let(:other_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: other_organization) }

    it "renders email hidden message" do
      expect(bike.email_visible_for?(organization)).to be_falsey
      expect(html).to include("email hidden")
      expect(html).not_to include(bike.owner_email)
    end
  end

  context "with bike_stickers enabled" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }

    it "renders sticker cell" do
      expect(html).to include("sticker_cell")
    end

    context "with bike_sticker param" do
      let(:bike_sticker) { FactoryBot.create(:bike_sticker, organization:) }
      let(:options) { {bike:, organization:, bike_sticker:} }

      it "renders link to claim sticker" do
        expect(html).to include("Link")
        expect(html).to include(bike_sticker.code)
      end
    end

    context "with sticker already on bike" do
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, organization:, bike:) }

      it "renders sticker code with edit link" do
        expect(html).to include(bike_sticker.pretty_code)
      end
    end
  end

  context "without bike_stickers enabled" do
    it "does not render sticker cell" do
      expect(html).not_to include("sticker_cell")
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders impounded cell" do
      expect(html).to include("impounded_cell")
    end

    context "with impounded bike" do
      let!(:impound_record) { FactoryBot.create(:impound_record, bike:, organization:) }

      it "renders impound date" do
        expect(bike.reload.status_impounded?).to be_truthy
        expect(html).to include("convertTime")
        expect(html).to include("impounded_cell")
      end
    end
  end

  context "with additional_registration_fields" do
    let(:options) { {bike:, organization:, additional_registration_fields: ["reg_phone"]} }

    it "renders registration field cell" do
      expect(html).to include("reg_phone_cell")
    end
  end

  context "with extra_registration_number" do
    before { bike.update_column(:extra_registration_number, "EXTRA-123") }

    it "renders extra registration number" do
      expect(html).to include("EXTRA-123")
      expect(html).to include("extra_registration_number_cell")
    end
  end
end
