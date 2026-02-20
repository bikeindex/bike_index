# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Strava search", :js, type: :system do
  it "renders the compiled strava_search SPA" do
    strava_app = FactoryBot.create(:doorkeeper_app, is_internal: true)
    stub_const("StravaJobs::ProxyRequester::STRAVA_DOORKEEPER_APP_ID", strava_app.id)

    user = FactoryBot.create(:user_confirmed)
    FactoryBot.create(:strava_integration, user:, athlete_id: "12345")
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

    visit "/strava_search"

    expect(page).to have_title("Strava search")
    # Verify the React app has mounted and rendered content into #root
    expect(page).to have_css("#root *", wait: 10)
  end
end
