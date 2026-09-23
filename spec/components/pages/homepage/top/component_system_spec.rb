# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Homepage::Top::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/homepage/top/component/default" }

  # An empty database - a review app's - has no RecoveryDisplays, so the showcase
  # renders its slides with no bike photo for them to swap in
  it "cycles the recovery showcase with no recovery displays" do
    expect(RecoveryDisplay.count).to eq 0
    visit preview_path

    expect(page).to have_css(".recovery-showcase")
    expect(page).to have_no_link("Read more recovery stories")
    page.execute_script("window.jsErrors = []; window.onerror = (message) => window.jsErrors.push(message)")

    find("button[aria-label='Next recovery story']").click
    expect(page).to have_link("Read more recovery stories")

    find("button[aria-label='Previous recovery story']").click
    expect(page).to have_link("Read more recovery stories")
    expect(page.evaluate_script("window.jsErrors")).to eq([])
  end
end
