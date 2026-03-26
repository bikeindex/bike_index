# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized impound records search", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:impound_records_path) { "/o/#{organization.to_param}/impound_records" }

  let!(:bike1) { FactoryBot.create(:bike, owner_email: "alice@example.com") }
  let!(:bike2) { FactoryBot.create(:bike, owner_email: "bob@example.com") }
  let!(:impound_record1) { FactoryBot.create(:impound_record_with_organization, organization:, user:, bike: bike1) }
  let!(:impound_record2) { FactoryBot.create(:impound_record_with_organization, organization:, user:, bike: bike2) }

  before do
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in!", wait: 10)
  end

  it "searches by email" do
    visit impound_records_path
    # Results load via turbo auto-submit (search--form controller)
    expect(page).to have_css("turbo-frame#organized_impound_records_results_frame table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    # search_no_js should NOT be in the URL (removed by JS controller)
    expect(page).not_to have_current_path(/search_no_js/)

    fill_in "search_email", with: "alice@example.com"
    find("#search-button").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
  end
end
