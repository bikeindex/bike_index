# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::SearchResults::BikesTable::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
  let(:bikes) { [bike] }
  let(:options) { {organization:, bikes:} }

  it "renders a table row with the bike data" do
    expect(component).to have_css("table")
    expect(component).to have_css("tbody tr", count: 1)
    expect(component).to have_text(bike.mnfg_name)
  end

  it "renders plain headers when not sortable" do
    expect(component).to have_css("th", text: "Registered")
    expect(component).not_to have_css("th a.twlink")
  end

  context "with a hidden-serial bike and an authorized org member" do
    let(:current_user) { FactoryBot.create(:organization_role_claimed, organization:).user }
    let(:options) { super().merge(current_user:) }
    let(:bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization).reload }

    it "passes the current user through so the hidden serial is revealed" do
      expect(bike.serial_hidden?).to be_truthy
      expect(component).to have_css(".serial_number_cell .serial-span", text: bike.serial_number.upcase)
      expect(component).to have_no_css(".serial_number_cell", text: "Hidden")
    end
  end

  context "with injected settings" do
    let(:other_org) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[reg_phone]) }
    let(:injected) { ComponentStructs::OrgSearchSettings.new(organization: other_org) }
    let(:options) { super().merge(settings: injected) }

    it "derives columns from the injected settings, not freshly built ones" do
      # the table's own organization has no reg_phone; the injected settings does
      expect(component).to have_css("th.reg_phone_cell", visible: :all)
    end
  end

  context "with every column's feature enabled" do
    let(:enabled_feature_slugs) do
      %w[bike_search avery_export bike_stickers impound_bikes registration_notes
        reg_address reg_extra_registration_number reg_organization_affiliation reg_phone reg_student_id]
    end
    let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:) }
    let(:options) { super().merge(settings:) }
    let(:panel) do
      with_request_url("/o/#{organization.to_param}/registrations") do
        render_inline(Pages::Org::Search::Settings::Component.new(settings:, skip_search_and_filters: true))
      end
    end

    # org--search-column-toggle hides any hideableColumn whose cell class isn't a
    # checked checkbox name, so a header with no checkbox can never be shown
    it "gives every hideable column a checkbox to toggle it" do
      headers = component.css("th.hideableColumn")
        .map { |th| th["class"].split.find { |klass| klass.end_with?("_cell") } }
      checkboxes = panel.css("input[type=checkbox]").map { |input| input["name"] }

      expect(headers).to match_array(headers.uniq)
      expect(headers - checkboxes).to eq []
    end
  end

  # The settings panel's checkboxes read the same column_renames, so this pins both
  context "with avery_export and registration_notes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search avery_export registration_notes] }

    it "labels the columns the way the table always has" do
      expect(component).to have_css("th.avery_cell", normalize_ws: true, exact_text: "Avery?")
      expect(component).to have_css("th.propulsion_type_cell", normalize_ws: true, exact_text: "Propulsion")
      expect(component).to have_css("th.notes_cell", normalize_ws: true, exact_text: "Registration Notes")
    end
  end

  context "with render_sortable" do
    let(:options) { {organization:, bikes:, render_sortable: true} }

    it "renders sortable header links" do
      expect(component).to have_css("th a.twlink")
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders the impound columns" do
      expect(component).to have_css("th.impound_id_cell", visible: :all, text: "Impound ID")
      expect(component).to have_css("th.impounded_cell", visible: :all, text: "Impounded")
    end
  end

  context "when a bike does not belong to the organization" do
    let(:enabled_feature_slugs) { %w[bike_search reg_phone reg_extra_registration_number] }
    let(:other_org) { FactoryBot.create(:organization) }
    let(:bike) do
      FactoryBot.create(:bike_organized,
        creation_organization: other_org,
        owner_email: "stranger@example.com",
        extra_registration_number: "SECRET-EXTRA",
        phone: "555-555-1212")
    end

    it "redacts every registration field, leaving public columns visible" do
      expect(component).to have_css("tbody tr", count: 1)
      expect(component).to have_text(bike.mnfg_name)
      expect(component).not_to have_text("stranger@example.com")
      expect(component).not_to have_text("555-555-1212")
      expect(component).not_to have_text("SECRET-EXTRA")
      hidden_text = "hidden, not registered with #{organization.short_name}"
      expect(component).to have_css(".owner_email_cell em.less-strong", text: hidden_text)
      expect(component).to have_css(".reg_phone_cell em.less-strong", text: hidden_text)
      expect(component).to have_css(".reg_extra_registration_number_cell em.less-strong", text: hidden_text)
    end
  end
end
