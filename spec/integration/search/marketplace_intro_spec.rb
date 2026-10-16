# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Marketplace intro", :js, type: :system do
  let(:cookie_name) { Pages::Search::MarketplaceIntro::Component::COOKIE_NAME }
  let(:intro_heading) { "The used bike marketplace from the bike registry." }

  def focused_text = page.evaluate_script("document.activeElement.textContent").squish

  it "hides, comes back, collapses for a search, and keeps Marketplace current in the nav" do
    resize_window(width: 1280, height: 900)
    visit "/"
    within("#primary-main-menu") { click_link "Marketplace" }
    expect(page).to have_css("h1", text: intro_heading)
    expect_axe_clean

    find("button[aria-label='Hide intro']").click
    expect(page).to have_css("h1", text: "Bike Index Marketplace")
    expect(page).to have_no_css("h1", text: intro_heading)
    # the clicked button is gone, so focus lands on the control that brings the intro back
    expect(focused_text).to eq "What makes this different?"
    expect(browser_cookie_value(cookie_name)).to eq "true"

    # after reload
    visit page.current_url
    expect(page).to have_css("h1", text: "Bike Index Marketplace")
    expect(page).to have_no_css("h1", text: intro_heading)

    click_button "What makes this different?"
    expect(page).to have_css("h1", text: intro_heading)
    expect(focused_text).to eq intro_heading
    expect(browser_cookie_value(cookie_name)).to be_nil

    fill_in "price_min_amount", with: "100"
    find_field("price_min_amount").send_keys(:return)
    expect(page).to have_current_path(/price_min_amount=100/)
    expect(page).to have_css("h1", text: "Bike Index Marketplace")
    expect(page).to have_no_css("h1", text: intro_heading)
    # a search isn't a dismissal
    expect(browser_cookie_value(cookie_name)).to be_nil

    click_button "What makes this different?"
    click_link "How selling works"
    expect(page).to have_css("h1", text: "How the Bike Index Marketplace works")
    within("#primary-main-menu") do
      expect(page).to have_css("a[aria-current]", text: /marketplace/i)
    end
  end
end
