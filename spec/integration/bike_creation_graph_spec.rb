# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bike creation graph", :js, type: :system do
  let!(:bike) { FactoryBot.create(:bike, created_at: Time.current - 1.day) }

  # Embedded in an iframe, so it renders with no layout and has to carry its own
  # chartkick - the canvas is what proves it did
  it "draws the chart" do
    visit "/bike_creation_graph?height=400"

    expect(page).to have_css("[id^='chart-'] canvas", wait: 10)
    expect(page).to have_css("[id^='chart-'][style*='height: 400px']")
  end
end
