# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Strava search", :js, type: :system do
  it "renders the compiled strava_search SPA" do
    visit "/strava_search"

    expect(page).to have_title("Strava search")
    # Verify the React app has mounted and rendered content into #root
    expect(page).to have_css("#root *", wait: 10)
  end
end
