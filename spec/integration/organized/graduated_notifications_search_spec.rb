# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized graduated notifications search", :js, type: :system do
  let(:earliest_time) { Time.current - 2.years }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[graduated_notifications], graduated_notification_interval: 1.year.to_i, created_at: earliest_time) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:graduated_notifications_path) { "/o/#{organization.to_param}/graduated_notifications" }

  let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: "alice@example.com", created_at: earliest_time) }
  let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: "bob@example.com", created_at: earliest_time) }
  let!(:graduated_notification1) { FactoryBot.create(:graduated_notification_bike_graduated, organization:, bike: bike1) }
  let!(:graduated_notification2) { FactoryBot.create(:graduated_notification_bike_graduated, organization:, bike: bike2) }

  before do
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "searches by email via turbo" do
    visit graduated_notifications_path
    # Results load via turbo auto-submit
    expect(page).to have_css("turbo-frame#graduated_notifications_results_frame table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    # search_no_js should NOT be in the URL (removed by JS controller)
    expect(page).not_to have_current_path(/search_no_js/)

    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
  end
end
