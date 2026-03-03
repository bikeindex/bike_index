# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized bikes search", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[bike_search]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:bikes_path) { "/o/#{organization.to_param}/bikes" }

  let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "alice@example.com") }
  let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "bob@example.com") }

  before do
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "searches by email" do
    visit bikes_path
    expect(page).to have_css("table.table", wait: 10)
    expect(page).to have_css("tbody tr", minimum: 2)

    fill_in "search_email", with: "alice@example.com"
    find("button[type]").click

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
    expect(page).to have_content("alice@example.com")
    expect(page).not_to have_content("bob@example.com")
  end

  it "submits when enter is pressed twice" do
    visit bikes_path
    expect(page).to have_css("table.table", wait: 10)

    fill_in "search_email", with: "alice@example.com"
    find("#search_email").send_keys(:return)

    expect(page).to have_current_path(/search_email=alice/, wait: 10)
    expect(page).to have_css("tbody tr", count: 1)
  end
end
