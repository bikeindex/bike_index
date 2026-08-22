# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Tabs::Component, :js, type: :system do
  let(:scrolling) { "nav[class*='tw:overflow-x-auto']" }

  it "scrolls the row only when the tabs are wider than it" do
    page.current_window.resize_to(500, 800)
    visit "/rails/view_components/ui/tabs/component/many_tabs"

    # Too narrow for seven tabs, so the row scrolls, and starts scrolled to the active last one
    expect(page).to have_css(scrolling)
    expect(page.evaluate_script("document.querySelector('nav').scrollLeft")).to be > 0
    expect_axe_clean

    page.current_window.resize_to(1600, 800)

    # Room for all of them now - a scroll container clips what sticks out of it vertically
    # and reserves room for a scrollbar, so it stops being one
    expect(page).to have_no_css(scrolling)
    expect(page.evaluate_script("getComputedStyle(document.querySelector('nav')).overflowX")).to eq "visible"
  end
end
