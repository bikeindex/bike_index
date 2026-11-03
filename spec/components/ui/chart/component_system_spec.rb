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

    visit("/rails/view_components/ui/chart/component/several_series")
    expect(page).to have_button("Registered (1,234)", wait: 5)
    expect(page).to have_button("Stolen (5)")
    expect(page).to have_button("Recovered (0)")
    expect(find_button("Stolen (5)")).to have_css(".twless-strong", text: "(5)")
    expect_axe_clean

    # The legend came out of the chart's height rather than adding to it
    heights = evaluate_script(<<~JS)
      [document.querySelector('[data-controller="ui--chart"]'), document.querySelector('[data-chart-legend]'), document.querySelector('[id^="chart-"]')]
        .map(element => element.getBoundingClientRect().height)
    JS
    expect(heights.first).to eq 300
    expect(heights.second + heights.third).to eq 300

    stolen = find_button("Stolen (5)")
    expect(stolen["aria-pressed"]).to eq "true"
    stolen.click
    expect(find_button("Stolen (5)")["aria-pressed"]).to eq "false"
    expect(page).to have_css("button[aria-pressed='false']:focus")

    visit("/rails/view_components/ui/chart/component/skip_legend_counts")
    expect(page).to have_button("Stolen", exact: true, wait: 5)
    click_button("Stolen", exact: true)
    expect(find_button("Stolen", exact: true)["aria-pressed"]).to eq "false"
    expect_axe_clean

    visit("/rails/view_components/ui/chart/component/pie_with_prefix")
    expect(page).to have_button("Donations ($1,234.50)", wait: 5)
    expect(page).to have_button("Stickers ($20.00)")
    find_button("Stickers ($20.00)").click
    expect(find_button("Stickers ($20.00)")["aria-pressed"]).to eq "false"
    expect_axe_clean
  end
end
