# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mobile nav menu", :js, type: :system do
  let(:pr_title) { "Stop the review app banner from covering the top of the mobile menu" }

  # The hamburgler is an opaque bar layered above the menu, so clicking the first
  # item only works if the menu opens clear of it
  def open_menu_and_search
    find("#primary_nav_hamburgler").click
    expect(page).to have_css("nav.primary-header-nav.menu-in", wait: 5)
    click_link "Search"
    expect(page).to have_current_path(search_registrations_path, ignore_query: true)
  end

  # The hamburgler only shows below the lg breakpoint, and the Playwright driver
  # defaults to desktop width
  before { page.current_window.resize_to(390, 844) }

  it "opens the menu clear of the hamburgler, with and without the review-app banner" do
    visit root_path
    open_menu_and_search

    # The banner pushes the navbar down, further still when its title wraps
    stub_const("ENV", ENV.to_hash.merge(
      "REVIEW_APP" => "pr-1234", "REVIEW_APP_PR_NUMBER" => "1234", "REVIEW_APP_PR_TITLE" => pr_title
    ))
    visit root_path
    expect(page).to have_content(pr_title)
    open_menu_and_search
  end
end
