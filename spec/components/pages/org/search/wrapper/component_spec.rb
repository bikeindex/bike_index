# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::Wrapper::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
  let(:pagy) { Pagy::Offset.new(count: 25, page: 1, limit: 10) }
  let(:search_stickers) { nil }
  let(:search_address) { nil }
  let(:search_status) { "all" }
  let(:search_page) { true }
  let(:bikes) { [bike] }
  let(:options) do
    {
      organization:,
      pagy:,
      bikes:,
      per_page: 10,
      params: {},
      interpreted_params: {},
      search_stickers:,
      search_address:,
      search_status:,
      search_page:
    }
  end

  it "renders the card header, column panel, table and footer" do
    expect(component).to have_css("table")
    expect(component).not_to have_text("Ordered by")
    expect(component).to have_css("tbody tr", count: 1)
    # the column panel ships collapsed, opened from the header button
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden\\!", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    expect(component).to have_button("Column settings", visible: :all)
    # footer
    expect(component).to have_text("showing 1–10 of 25")
    expect(component).to have_css("select#per_page_select")
    # bike data in cells
    expect(component).to have_text(bike.mnfg_name)
    # the table bleeds to the page's edges once the card is full bleed
    expect(component.at_css("div:has(> [data-controller~='org--bikes-table-overflow'])")[:class].split)
      .to include(*described_class::TABLE_BLEED_CLASSES.split)
    # the card marks itself for the frame's loading swap, and the rows swap off the
    # frame's tw:group for the spinner that replaces them
    expect(component).to have_css(".search-results-card", visible: :all)
    expect(component).to have_css(".tw\\:group-\\[\\[busy\\]\\]\\:block", visible: :all)
    expect(component.at_css("div:has(> [data-controller~='org--bikes-table-overflow'])")[:class].split)
      .to include("tw:group-[[busy]]:hidden")
    expect(component).to have_text("Loading results...")
  end

  context "with result_view cards" do
    let(:sort_state) { ComponentStructs::SortState.new(search_params: {serial: "xyz"}, sort: "mnfg_name", direction: "asc") }
    let(:options) { super().merge(result_view: "cards", sort_state:) }

    it "marks the chip active, carries the search into the other one's link, and renders cards" do
      expect(component).to have_css("a[data-active='true']", text: "Cards")
      expect(component).to have_link("Table", href: /search_result_view=table/)
      expect(component).to have_link("Table", href: /serial=xyz/)
      expect(component).to have_css("ul li", text: bike.mnfg_name)
      expect(component).not_to have_css("table")
      expect(component).not_to have_button("Column settings", visible: :all)
      expect(component).to have_text("Ordered by Manufacturer, ascending")
      expect(component).to have_css("button[aria-label='Switch to the table view to change ordering']", text: "?")
    end

    context "with csv_exports enabled" do
      let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

      it "renders no export" do
        expect(component).to have_css("ul li", text: bike.mnfg_name)
        expect(component).not_to have_link("Export CSV", visible: :all)
      end
    end

    context "with result_view list" do
      let(:options) { super().merge(result_view: "list") }

      it "renders rows" do
        expect(component).to have_css("a[data-active='true']", text: "List")
        expect(component).to have_css("ul li.tw\\:border-l-4", text: bike.mnfg_name)
        expect(component).not_to have_css("table")
        expect(component).not_to have_button("Column settings", visible: :all)
      end
    end

    context "with an unknown view" do
      let(:options) { super().merge(result_view: "nonsense") }

      it "falls back to the table" do
        expect(component).to have_css("a[data-active='true']", text: "Table")
        expect(component).to have_css("table")
      end
    end

    context "without search_page" do
      let(:search_page) { false }

      it "renders the table" do
        expect(component).to have_css("table")
        expect(component).not_to have_text("View as")
      end
    end
  end

  context "without search_page" do
    let(:search_page) { false }

    it "renders the column settings button without the search's actions, and brings its own controllers" do
      expect(component).to have_css("table")
      # no results frame above this card, so nothing sets [busy] and there's no loading swap
      expect(component).not_to have_css(".search-results-card", visible: :all)
      expect(component).not_to have_text("Loading results...")
      expect(component).to have_css("[data-controller~='org--search-column-settings']")
      expect(component).to have_button("Column settings", visible: :all)
      # the header's button is the only one - the panel doesn't carry the legacy one
      expect(component).to have_css("[data-ui--collapse-target='trigger']", count: 1, visible: :all)
      expect(component.at_css("div:has(> [data-controller~='org--bikes-table-overflow'])")[:class].split)
        .not_to include(*described_class::TABLE_BLEED_CLASSES.split)
    end

    context "with csv_exports enabled" do
      let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

      it "renders no export, since this page's params aren't a search of what's shown" do
        expect(component).not_to have_text("Export CSV")
      end
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders impound columns" do
      expect(component).to have_css("th.impound_id_cell", visible: :all, text: "Impound ID")
    end
  end

  context "with search_all" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }
    let(:options) { super().merge(search_all: true) }

    it "disables the export, which would reach past the organization, and says why" do
      expect(component).to have_css("[data-controller='ui--tooltip'] button a[aria-disabled='true']:not([href])", text: "Export CSV")
      expect(component).to have_css("[role=tooltip]", text: 'Uncheck "Search all registrations"', visible: :all)
      expect(component).to have_text("25 matches")
    end

    context "with the count at its limit" do
      let(:pagy) { Pagy::Offset.new(count: 1_000, page: 1, limit: 10) }

      it "says it stopped counting there" do
        expect(component).to have_text("Over 1,000 matches")
      end
    end
  end

  context "with a single match" do
    let(:pagy) { Pagy::Offset.new(count: 1, page: 1, limit: 10) }

    it "counts it in the singular" do
      expect(component).to have_text(/1 match\b/)
    end
  end

  context "with over 1,000 matches, not searching all" do
    let(:pagy) { Pagy::Offset.new(count: 1_001, page: 1, limit: 10) }

    it "shows the count" do
      expect(component).to have_text("1,001 matches")
    end
  end

  context "when bike is user_hidden and org cannot edit" do
    let(:bike) do
      FactoryBot.create(:bike_organized,
        creation_organization: organization,
        user_hidden: true,
        claimed: true,
        can_edit_claimed: false)
    end

    it "renders the serial number" do
      expect(component).to have_css("tbody tr", count: 1)
      expect(component).to have_text(bike.serial_display(organization:))
    end
  end

  context "with csv_exports enabled" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

    it "renders the export in the header, beside the column settings button" do
      expect(component).to have_link("Export CSV", visible: :all)
      expect(component).not_to have_css("[data-ui--collapse-target='content'] a", text: "Export CSV", visible: :all)
    end
  end

  context "when bike does not belong to the organization" do
    let(:enabled_feature_slugs) { %w[bike_search reg_phone reg_extra_registration_number bike_stickers] }
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
      hidden_text = "Hidden because it is not registered with #{organization.short_name}"
      %w[owner_email_cell owner_name_cell reg_phone_cell reg_extra_registration_number_cell].each do |cell|
        expect(component).to have_css(".#{cell} button em.less-strong", text: "hidden")
        expect(component).to have_css(".#{cell} [role=tooltip]", text: hidden_text, visible: :all)
      end
    end
  end
end
