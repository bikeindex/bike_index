# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized parking notifications", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:base_url) { "/o/#{organization.to_param}/parking_notifications" }

  let!(:registered) { FactoryBot.create(:parking_notification_organized, organization:, user:) }
  let!(:unregistered) { FactoryBot.create(:parking_notification_unregistered, organization:, user:) }
  let!(:abandoned) { FactoryBot.create(:parking_notification_organized, organization:, user:, kind: "appears_abandoned_notification") }
  let!(:retrieved) { FactoryBot.create(:parking_notification_organized, :retrieved, organization:, user:) }

  before do
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    find(".alert-success .close").click
    find("#passive_organization_submenu").click
    within(".current-organization-submenu") { click_link "Parking notifications" }
    expect(page).to have_current_path(/\A#{Regexp.escape(base_url)}(\?|\z)/, wait: 10)
  end

  def click_filter(text)
    link = find("a.linkWithSortableSearchParams", text: text, visible: :all)
    # Bootstrap dropdowns hide menu items until the parent toggle is clicked.
    link.find(:xpath, "ancestor::li[contains(@class,'nav-item')][1]").find("a.dropdown-toggle").click
    link.click
  end

  def row_for(notification) = "tr[data-recordid='#{notification.id}']"

  it "filters notifications through the dropdown menus and toggles them off when re-clicked" do
    # Default view (status=current) loads three current notifications via JSON.
    expect(page).to have_css(row_for(registered), wait: 20)
    expect(page).to have_css(row_for(unregistered))
    expect(page).to have_css(row_for(abandoned))
    expect(page).to have_css("tr.record-row", count: 3)

    # Regression: the click handler reads data-urlparams (not href), so this used to apply
    # only_unregistered due to a copy-paste in the template.
    click_filter("Registered bikes only")
    expect(page).to have_css(row_for(registered), wait: 20)
    expect(page).to have_css(row_for(abandoned))
    expect(page).not_to have_css(row_for(unregistered))
    expect(page).to have_css("tr.record-row", count: 2)

    # Clicking the active item toggles it off — unregistered comes back.
    click_filter("Registered bikes only")
    expect(page).to have_css(row_for(unregistered), wait: 20)
    expect(page).to have_css("tr.record-row", count: 3)

    # "Only unregistered bikes" hides the registered ones.
    click_filter("Only unregistered bikes")
    expect(page).to have_css(row_for(unregistered), wait: 20)
    expect(page).not_to have_css(row_for(registered))
    expect(page).not_to have_css(row_for(abandoned))
    expect(page).to have_css("tr.record-row", count: 1)

    # "All bikes" shows everything again.
    click_filter("All bikes")
    expect(page).to have_css("tr.record-row", count: 3, wait: 20)

    # Status dropdown: "Resolved" shows the retrieved notification.
    click_filter("Resolved notifications")
    expect(page).to have_css(row_for(retrieved), wait: 20)
    expect(page).not_to have_css(row_for(registered))
    expect(page).to have_css("tr.record-row", count: 1)

    # Toggle the active status off — back to the three current notifications.
    click_filter("Resolved notifications")
    expect(page).to have_css(row_for(registered), wait: 20)
    expect(page).to have_css("tr.record-row", count: 3)
    expect(page).not_to have_css(row_for(retrieved))

    # Kind dropdown narrows to a single kind.
    click_filter("Appears abandoned notifications")
    expect(page).to have_css(row_for(abandoned), wait: 20)
    expect(page).not_to have_css(row_for(registered))
    expect(page).to have_css("tr.record-row", count: 1)
  end
end
