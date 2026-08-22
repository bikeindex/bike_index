# frozen_string_literal: true

require "rails_helper"

# The sidebar's current row is UI::ActiveLink's, resolved in the browser, and the group
# holding it is opened from that — neither is visible to a component spec.
RSpec.describe "Organization sidebar", :js, type: :system do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, :with_auto_user,
      enabled_feature_slugs: %w[impound_bikes parking_notifications bike_stickers])
  end
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:slug) { organization.to_param }

  before do
    # Above the sidebar's 1100px auto-collapse breakpoint, so it's the full column
    # rather than the icon rail, which hides every row's label
    page.current_window.resize_to(1280, 1600)
    using_wait_time(10) do
      visit new_session_path
      fill_in "Email", with: user.email
      click_button "Continue"
      fill_in "Password", with: "testthisthing7$"
      click_button "Log in"
      dismiss_flash_messages
    end
  end

  def expect_open(label)
    expect(page).to have_css("#org_sidebar_nav button[aria-expanded='true']", text: label)
  end

  # data-active is what the is-active variant colors the row with
  def expect_current_group(label)
    expect(page).to have_css("#org_sidebar_nav button[data-active='true']", text: label, count: 1)
  end

  let(:scroller) { "[data-page-block--org-sidebar-target='scroller']" }

  def scroller_top
    page.evaluate_script("document.querySelector(\"#{scroller}\").scrollTop")
  end

  def current_row_in_view?
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector('#org_sidebar_nav a[aria-current]')
        const scroller = document.querySelector("#{scroller}")
        if (!row || !scroller) return false
        const box = row.getBoundingClientRect()
        const view = scroller.getBoundingClientRect()
        return box.top >= view.top && box.bottom <= view.bottom
      })()
    JS
  end

  it "opens the group holding the page, follows a row, and moves the current row with it" do
    visit "/o/#{slug}/impound_records"

    # The group holding the page is the one open, and the only one flagged current;
    # the others stay shut
    expect_open("Impounded Vehicles")
    expect_current_group("Impounded Vehicles")
    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "Search Impounded Vehicles"
    expect(page).to have_no_css "#org_sidebar_nav button[aria-expanded='true']",
      text: "#{organization.short_name} Registrations"

    # Reaching another section's row means opening that section first, the way a reader does
    within("#org_sidebar_nav") { click_button "#{organization.short_name} Registrations" }

    # Opening a group is not being on it -- the flag stays with the page
    expect_open("#{organization.short_name} Registrations")
    expect_current_group("Impounded Vehicles")

    within("#org_sidebar_nav") { click_link "Search Registrations" }

    expect(page).to have_current_path("/o/#{slug}/registrations", ignore_query: true)
    expect_open("#{organization.short_name} Registrations")
    expect_current_group("#{organization.short_name} Registrations")
    expect(page).to have_css "#org_sidebar_nav a[aria-current='page']", text: "Search Registrations"
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", text: "Search Impounded Vehicles"

    # Short enough that the menu scrolls, with Manage users past its fold
    page.current_window.resize_to(1280, 400)
    visit "/o/#{slug}/users"

    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "Manage users"
    # The reveal scrolls smoothly, so the row lands over the next few frames
    wait_for { current_row_in_view? }
    # Guards this against going vacuous on a menu that turns out to fit
    expect(scroller_top).to be > 0
  end

  it "tells the two add-a-bike rows apart by the param" do
    visit "/o/#{slug}/registrations/new"

    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "Add a bike"
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", text: "New unregistered notification"

    visit "/o/#{slug}/bikes/new?parking_notification=true"

    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "New unregistered notification"
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", text: "Add a bike"

    # Going back to the old view moves add-a-bike onto organized/bikes#new alongside the
    # notification's row, where the query string is all that tells the two apart
    visit "/o/#{slug}/registrations/new"
    click_link "Go back to the old view"
    click_link "Add a bike"

    expect(page).to have_css "#org_sidebar_nav a[aria-current]", text: "Add a bike"
    expect(page).to have_no_css "#org_sidebar_nav a[aria-current]", text: "New unregistered notification"
  end

  # The sidebar stands in for the navbar on every page a member sees, including ones no
  # row points at — where the design's default of the first group open stands
  it "opens the first group on a page no row matches, and leaves the organization from it" do
    visit "/my_account"

    expect_open("#{organization.short_name} Registrations")
    # The scroller holds the menu rows -- the account block below it points at /my_account,
    # so one of its own rows is current here
    expect(page).to have_no_css "[data-page-block--org-sidebar-target='scroller'] a[aria-current]", visible: :all
    # Open, but no more the page than any other group
    expect(page).to have_no_css "#org_sidebar_nav button[data-active='true']"

    # Leaving the organization shouldn't also leave the page, anywhere the page survives it
    expect(leave_link[:href]).to eq "#{page.server_url}/my_account?organization_id=false"

    dismiss_donation_modal

    open_account_menu
    click_link "View without any organization"

    # The organization is what the sidebar stands in for, so dropping it hands the navbar
    # back -- on the page they were already reading
    expect(page).to have_current_path("/my_account", ignore_query: true)
    expect(page).to have_no_css "#org_sidebar_nav"

    # Back in through the navbar's switcher, which lands on the organization's registrations
    find("button[aria-label='Settings']").click
    click_link "Switch to #{organization.name}"

    expect(page).to have_current_path("/o/#{slug}/registrations", ignore_query: true)
    expect_current_group("#{organization.short_name} Registrations")

    # Inside the organization interface there's no page to stay on, so the row keeps the
    # homepage it renders pointing at
    expect(leave_link[:href]).to eq "#{page.server_url}/?organization_id=false"

    open_account_menu
    click_link "View without any organization"

    expect(page).to have_current_path("/", ignore_query: true)
  end

  # The account block is a UI::Dropdown, so its rows are hidden until it opens
  def open_account_menu
    find("#org_sidebar_nav button[data-ui--dropdown-target='button']", text: user.email).click
  end

  def leave_link
    find("#org_sidebar_nav a", text: "View without any organization", visible: :all)
  end
end
