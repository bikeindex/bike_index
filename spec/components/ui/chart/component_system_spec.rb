# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Chart::Component, :js, type: :system do
  # the preview charts real registrations, and chartkick renders "No data" rather than a
  # canvas for an empty series
  let!(:bike) { FactoryBot.create(:bike, created_at: Time.current - 1.day) }

  it "renders a chart" do
    visit("/rails/view_components/ui/chart/component/bikes_by_status")

    # the canvas, rather than the placeholder div: chartkick and Chart.js load on
    # demand from ui--chart, so this is what proves they arrived
    expect(page).to have_css("[id^='chart-'] canvas")
    expect_axe_clean
  end
end
