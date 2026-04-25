# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSearch::Component, type: :component do
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
  let(:skip_search_and_filters) { false }
  let(:bikes) { [bike] }
  let(:options) do
    {
      organization:,
      pagy:,
      bikes:,
      per_page: 10,
      params: {},
      interpreted_params: {},
      sortable_search_params: {},
      search_stickers:,
      search_address:,
      search_status:,
      skip_search_and_filters:,
      stolenness: "all",
      time_range: 1.year.ago..Time.current
    }
  end

  it "renders table with form, checkboxes, and bike data" do
    expect(component).to have_css("table")
    expect(component).to have_css("tbody tr", count: 1)
    expect(component).to have_css("[data-org--registration-search-target='settings']", visible: :all)
    # Search form
    expect(component).to have_css("#Search_Form")
    # checkboxes
    expect(component).to have_css("[data-org--registration-search-target='settings'].tw\\:hidden\\!", visible: :all)
    expect(component).to have_css("input[type='checkbox']", visible: :all)
    # pagination
    expect(component).to have_css(".paginate-container")
    expect(component).to have_css("select#per_page_select")
    # bike data in cells
    expect(component).to have_text(bike.mnfg_name)
  end

  context "with skip_search_and_filters" do
    let(:skip_search_and_filters) { true }

    it "renders table without search form" do
      expect(component).to have_css("table")
      expect(component).not_to have_css("#Search_Form")
    end
  end

  context "with bike_stickers enabled" do
    let(:enabled_feature_slugs) { %w[bike_search bike_stickers] }

    it "renders sticker filter radios" do
      expect(component).to have_text("Stickers")
      expect(component).to have_css("input[type='radio'][name='search_stickers']", visible: :all)
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders impound status filter radios and impound columns" do
      expect(component).to have_text("Status")
      expect(component).to have_css("input[type='radio'][name='search_status'][value='not_impounded']", visible: :all)
      expect(component).to have_css("th.impound_id_cell", visible: :all, text: "Impound ID")
      expect(component).to have_css("th.impounded_cell", visible: :all, text: "Impounded")
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
      expect(component).to have_link(text: /Create export/, visible: :all)
    end
  end
end
