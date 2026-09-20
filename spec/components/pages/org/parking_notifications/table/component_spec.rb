# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::ParkingNotifications::Table::Component, type: :component do
  let(:component) do
    with_request_url("/o/#{organization.to_param}/parking_notifications") do
      render_inline(described_class.new(parking_notifications: [parking_notification],
        current_organization: organization, **options))
    end
  end
  let(:options) { {} }
  let(:routes) { Rails.application.routes.url_helpers }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
  let(:parking_notification) do
    FactoryBot.create(:parking_notification_organized, organization:, message: "Move it", internal_notes: "called twice")
  end

  it "renders a row per notification, with every column but the optional ones" do
    expect(component).to have_css("tbody tr", count: 1)
    expect(component).to have_css("th", text: "Bike")
    expect(component).to have_css("th", text: "Status")
    expect(component).to have_css("th", text: "Resolved")
    expect(component).not_to have_css("th", text: "Address")

    expect(component).to have_link(href: routes.organization_parking_notification_path(parking_notification, organization_id: organization.id))
    expect(component).to have_link(href: routes.bike_path(parking_notification.bike))
    expect(component).to have_content(parking_notification.kind_humanized)
    expect(component).to have_css("td", text: /Notes: called twice.*Message: Move it/)
    # The map columns and their per-row coordinates only come with map_rows
    expect(component).not_to have_css(".map-cell")
    expect(component).not_to have_css("tr[data-latitude]")
    expect(component).not_to have_css(".multiselect-cell")
  end

  context "with map_rows and render_multiselect" do
    let(:options) { {map_rows: true, render_multiselect: true} }

    it "hooks the rows and the checkboxes up to the index controller" do
      expect(component).to have_css("tr[data-org--parking-notifications-index-target='row']" \
        "[data-latitude='#{parking_notification.latitude}'][data-longitude='#{parking_notification.longitude}']")
      expect(component).to have_css("td.map-cell button[data-action~='org--parking-notifications-index#showOnMap']")

      # Hidden until "retrieve/send repeat notification" reveals the column
      expect(component).to have_css("th.multiselect-cell.tw\\:hidden button[data-action~='table-multi-checkbox#toggleAll']", visible: :all)
      expect(component).to have_css("input[type=checkbox][name='ids[#{parking_notification.id}]']", visible: :all)
    end
  end

  context "with the skip flags the bike page passes" do
    let(:options) { {skip_bike: true, render_address: true, skip_status: true, skip_resolved: true} }

    it "renders the address instead" do
      expect(component).to have_css("th", text: "Address")
      expect(component).to have_content(parking_notification.formatted_address_string)
      expect(component).not_to have_css("th", text: "Bike")
      expect(component).not_to have_css("th", text: "Status")
      expect(component).not_to have_css("th", text: "Resolved")
    end
  end

  context "with render_sortable" do
    let(:options) { {render_sortable: true, sort_state: ComponentStructs::SortState.new(search_params: {search_status: "all"}, sort: "created_at", direction: "desc")} }

    it "links the sortable headers and the notifying user, carrying the search params" do
      expect(component).to have_css("th a", text: /Created/)
      expect(component).to have_css("th a", text: /Type/)
      expect(component).to have_css("th a", text: /Notification#/)
      expect(component).to have_link(parking_notification.user.display_name,
        href: routes.organization_parking_notifications_path(organization_id: organization.to_param, search_status: "all", user_id: parking_notification.user_id))
    end
  end
end
