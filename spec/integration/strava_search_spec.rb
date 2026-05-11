# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Strava search", :js, type: :system do
  it "renders the compiled strava_search SPA" do
    strava_app = FactoryBot.create(:doorkeeper_app, is_internal: true)
    stub_const("Integrations::Strava::ProxyRequester::STRAVA_DOORKEEPER_APP_ID", strava_app.id)

    user = FactoryBot.create(:user_confirmed)
    FactoryBot.create(:strava_integration, user:, strava_id: "12345")
    Doorkeeper::AccessToken.create!(
      application_id: strava_app.id,
      resource_owner_id: user.id,
      scopes: "public",
      expires_in: Doorkeeper.configuration.access_token_expires_in
    )

    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in")

    visit "/strava_search"

    # Verify the React app has mounted and rendered content into #root
    expect(page).to have_css("#root *", wait: 10)
    expect(page).to have_title("Strava search")
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
  end
end
