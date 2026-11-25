# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::ImpoundSettings::Component, type: :component do
  let(:impound_configuration) { FactoryBot.create(:impound_configuration, display_id_prefix: "BB-", expiration_period_days: 90) }
  let(:organization) { impound_configuration.organization }
  let(:component) { render_inline(described_class.new(organization:, impound_configuration:)) }
  let(:form) { component.at_css("form[action='/o/#{organization.to_param}/manage_impounding'][method=post]") }

  it "renders the settings, with the next ID and a prefix preview" do
    expect(component).to have_css("h1", text: "#{organization.name} impound settings")
    expect(form.css("input[name='impound_configuration[display_id_prefix]']").first["value"]).to eq "BB-"
    expect(form.at_css("input[name='impound_configuration[expiration_period_days]']")["value"]).to eq "90"
    expect(form.at_css("[data-org--impound-settings-target=nextId]").text.strip).to eq "BB-1"
    expect(form.at_css("[data-org--impound-settings-target=unsaved]")["class"]).to include "tw:hidden"
    expect(form["data-controller"]).to eq "org--impound-settings"
    expect(component).to_not have_text "Impound location"
    expect(component).to_not have_text "Bulk import"
  end

  context "with previous prefixes" do
    before do
      FactoryBot.create(:impound_record, organization:, display_id_prefix: "2025-")
      FactoryBot.create(:impound_record, organization:)
      ImpoundRecord.where(display_id_prefix: "2025-").update_all(display_id_integer: 7)
    end

    it "offers them as buttons that fill in the prefix" do
      buttons = form.css("button[data-action='org--impound-settings#use']")
      expect(buttons.map { it["data-org--impound-settings-prefix-param"] }).to match_array(%w[2025- BB-])
      expect(component).to have_text "no prefix"
      expect(JSON.parse(form["data-org--impound-settings-next-ids-value"])).to include("2025-" => 8, "BB-" => 2)
    end
  end

  context "with feature gates" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[impound_bikes impound_bikes_locations show_bulk_import_impound]) }
    let(:impound_configuration) { organization.fetch_impound_configuration }

    it "links to set locations, and bulk import" do
      expect(component).to have_link "Set impound locations", href: "/o/#{organization.to_param}/manage/locations"
      expect(component).to have_link "Import impounded bikes", href: "/o/#{organization.to_param}/bulk_imports/new?kind=impounded"
    end

    context "with a default location" do
      let!(:location) { FactoryBot.create(:location, organization:, impound_location: true, default_impound_location: true) }

      it "names it" do
        expect(component).to have_css("strong", text: location.name)
        expect(component).to have_link "Update locations"
      end
    end
  end
end
