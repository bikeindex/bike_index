# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Navbar", :js, type: :system do
  let(:pr_title) { "Stop the review app banner from covering the top of the mobile menu" }

  # The hamburgler is an opaque bar layered above the menu, so clicking the first
  # item only works if the menu opens clear of it
  def open_menu_and_search
    find("#primary_nav_hamburgler").click
    expect(page).to have_css("nav.primary-header-nav.menu-in", wait: 5)
    within("nav.primary-header-nav") { click_link "Search" }
    expect(page).to have_current_path(search_registrations_path, ignore_query: true)
  end

  # The hamburgler only shows below the lg breakpoint, and the Playwright driver
  # defaults to desktop width
  before { page.current_window.resize_to(390, 844) }

  it "opens the menu clear of the hamburgler, with and without the review-app banner" do
    visit root_path

    # Everything but the signup link is behind the hamburgler at this width
    expect(page).to have_css(".hamburgler button[aria-expanded='false']")
    expect(page).to have_link("Sign up", count: 1)
    expect(page).to have_css(".center-navbar-signup-link")
    within("nav.primary-header-nav") { expect(page).to have_no_link("Search") }
    expect_axe_clean

    open_menu_and_search

    # The banner pushes the navbar down, further still when its title wraps
    stub_const("ENV", ENV.to_hash.merge(
      "REVIEW_APP" => "pr-1234", "REVIEW_APP_PR_NUMBER" => "1234", "REVIEW_APP_PR_TITLE" => pr_title
    ))
    visit root_path
    expect(page).to have_content(pr_title)
    open_menu_and_search
  end

  # The two-step login and the flash both animate, and a click waits for its target
  # to settle before it lands -- that wait is Capybara's 2s default
  def sign_in(user)
    using_wait_time(10) do
      visit new_session_path
      fill_in "Email", with: user.email
      click_button "Continue"
      fill_in "Password", with: "testthisthing7$"
      click_button "Log in"
      expect(page).to have_no_current_path(new_session_path, wait: 10)
    end
  end

  context "signed in without an organization" do
    let!(:user) { FactoryBot.create(:user_confirmed) }

    # The gear is icon-only, so its aria-label is the only thing to find it by
    let(:settings_toggle) { "button[aria-label='Settings']" }

    it "opens the settings dropdown at desktop width, and folds it into the hamburgler" do
      sign_in(user)

      page.current_window.resize_to(1440, 900)
      visit root_path

      # The closed dropdown's items are rendered, out of view
      expect(page).to have_no_link("Logout")
      expect_axe_clean

      find(settings_toggle).click

      expect(page).to have_link("Logout")
      expect_axe_clean

      # Escape from inside the dropdown hands focus back to the toggle, rather than
      # leaving it on a link that just became display:none
      find_link("Logout").send_keys(:escape)

      expect(page).to have_no_link("Logout")
      expect(page.evaluate_script("document.activeElement.id")).to eq "setting_submenu"

      find(settings_toggle).click

      expect(page).to have_link("Logout")

      find("body").click

      expect(page).to have_no_link("Logout")

      page.current_window.resize_to(390, 844)

      # No room for the gear on a phone, so its items sit in the hamburgler menu
      expect(page).to have_no_css(settings_toggle)
      find("#primary_nav_hamburgler").click

      expect(page).to have_link("Logout")
    end
  end

  context "signed in with an organization" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let!(:user) { FactoryBot.create(:organization_admin, organization:) }

    it "renders the sidebar in place of the navbar, as a column and then behind the hamburgler" do
      sign_in(user)

      page.current_window.resize_to(1440, 900)
      visit root_path

      expect(page).to have_no_css(".primary-header-nav")
      expect(page).to have_css("#org_sidebar_nav")
      expect(page).to have_button("Brakebills Registrations")
      expect_axe_clean

      # The account block is a UI::Dropdown, so its items are hidden until it opens
      expect(page).to have_no_link("Log out")
      find("button[data-ui--dropdown-target='button']", text: user.email).click

      expect(page).to have_link("Log out")
      expect(page).to have_link("Your registrations")
      expect_axe_clean

      page.current_window.resize_to(390, 844)

      # Below the breakpoint the menu is behind the hamburgler
      expect(page).to have_no_button("Brakebills Registrations")
      find("#org_sidebar_hamburgler").click

      expect(page).to have_button("Brakebills Registrations")
    end
  end
end
