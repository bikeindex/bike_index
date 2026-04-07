# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Chart::Component, :js, type: :system do
  it "renders a chart" do
    visit("/rails/view_components/ui/chart/component/bikes_by_status")

    expect(page).to have_css("[id^='chart-']")
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
  end
end
