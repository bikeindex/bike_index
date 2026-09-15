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
      search_page:,
      stolenness: "all",
      humanized_time_range: "in the past year"
    }
  end

  it "renders the card header, column panel, table and footer" do
    expect(component).to have_css("table")
    expect(component).to have_css("tbody tr", count: 1)
    # the column panel ships collapsed, opened from the header button
    expect(component).to have_css("[data-org--search-target='columns'].tw\\:hidden\\!", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    expect(component).to have_button("Column settings", visible: :all)
    expect(component).to have_link("Add a bike", visible: :all)
    # footer
    expect(component).to have_text("showing 1–10 of 25")
    expect(component).to have_css("select#per_page_select")
    # bike data in cells
    expect(component).to have_text(bike.mnfg_name)
  end

  context "without search_page" do
    let(:search_page) { false }

    it "renders the table with no header actions, and brings its own controllers" do
      expect(component).to have_css("table")
      expect(component).to have_css("[data-controller~='org--search-column-toggle']")
      expect(component).not_to have_button("Column settings", visible: :all)
      expect(component).not_to have_link("Add a bike", visible: :all)
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders impound columns" do
      expect(component).to have_css("th.impound_id_cell", visible: :all, text: "Impound ID")
      expect(component).to have_css("th.impounded_cell", visible: :all, text: "Impounded")
    end
  end

  context "with search_all" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }
    let(:options) { super().merge(search_all: true) }

    it "drops the export, which would reach past the organization" do
      expect(component).not_to have_link("Export CSV", visible: :all)
      expect(component).not_to have_link(text: /Create export/, visible: :all)
      # the count sentence stops naming the organization
      expect(component).not_to have_text("matching for #{organization.short_name}")
    end
  end

  context "with search_stickers filter active" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }
    let(:search_stickers) { "with" }

    it "displays active filter description" do
      expect(component).to have_text("with stickers")
    end
  end

  context "with search_address filter active" do
    let(:search_address) { "without_street" }

    it "displays active filter description" do
      expect(component).to have_text("no address")
    end
  end

  context "with search_status filter active" do
    let(:search_status) { "stolen" }

    it "displays active filter description" do
      expect(component).to have_text("only stolen")
    end
  end

  context "when bike is user_hidden and org cannot edit" do
    let(:current_user) { FactoryBot.create(:organization_role_claimed, organization:).user }
    let(:options) do
      super().merge(current_user:)
    end
    let(:bike) do
      FactoryBot.create(:bike_organized,
        creation_organization: organization,
        user_hidden: true,
        claimed: true,
        can_edit_claimed: false)
    end

    it "renders the serial number" do
      expect(component).to have_css("tbody tr", count: 1)
      expect(component).to have_text(bike.serial_display(current_user))
    end
  end

  context "with csv_exports enabled" do
    let(:enabled_feature_slugs) { %w[bike_search csv_exports] }

    it "renders export link" do
      expect(component).to have_link("Export CSV", visible: :all)
      expect(component).to have_link(text: /Create export/, visible: :all)
    end
  end

  context "when bike does not belong to the organization" do
    let(:enabled_feature_slugs) { %w[bike_search reg_phone bike_stickers] }
    let(:other_org) { FactoryBot.create(:organization) }
    let(:bike) do
      FactoryBot.create(:bike_organized,
        creation_organization: other_org,
        owner_email: "stranger@example.com",
        extra_registration_number: "SECRET-EXTRA",
        phone: "555-555-1212")
    end

    it "redacts private fields and leaves non-private columns visible" do
      expect(component).to have_css("tbody tr", count: 1)
      expect(component).to have_text(bike.mnfg_name)
      # Private contact info is redacted with the shared hidden marker
      expect(component).not_to have_text("stranger@example.com")
      expect(component).not_to have_text("555-555-1212")
      hidden_text = "hidden, not registered with #{organization.short_name}"
      expect(component).to have_css(".owner_email_cell em.less-strong", text: hidden_text)
      expect(component).to have_css(".owner_name_cell em.less-strong", text: hidden_text)
      expect(component).to have_css(".reg_phone_cell em.less-strong", text: hidden_text)
      # Non-private columns are visible
      expect(component).to have_text("SECRET-EXTRA")
    end
  end
end
