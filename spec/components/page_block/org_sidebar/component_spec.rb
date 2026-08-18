# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::OrgSidebar::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed, email: "kdewey@brakebills.edu") }
  let(:organization) { FactoryBot.create(:organization_brakebills) }
  let!(:organization_role) do
    FactoryBot.create(:organization_role_claimed, user: current_user, organization:, role: "admin")
  end
  let(:instance) { described_class.new(organization:, current_user:) }
  let(:component) { with_request_url("/") { render_inline(instance) } }

  it "renders the header, the groups and the account block" do
    expect(component).to have_css "nav#org_sidebar_nav"
    expect(component).to have_text "ADMIN PANEL"
    expect(component).to have_text "Brakebills"
    # The mobile bar carries its own copy of the logo
    expect(component).to have_css "img[alt='Bike Index']", count: 2

    expect(component.css("[aria-controls^='org_sidebar_group_']").map { |button| button.text.strip })
      .to eq(["Brakebills Registrations", "Impounded Vehicles", "Parking Notifications",
        "Bulk Import & Export", "Brakebills Settings"])

    expect(component).to have_css "button[data-ui--dropdown-target='button']", text: "kdewey@brakebills.edu"
    expect(component.css("ul[role='menu'] li[role='menuitem'] a").map(&:text))
      .to eq(["Your registrations", "Register a new bike", "kdewey@brakebills.edu settings", "Log out"])
  end

  # Which row is current is ui--active-link's, in the browser, so every row states what
  # it takes to be the page it points at rather than whether it is one
  it "hands each row to UI::ActiveLink to resolve" do
    rows = component.css("nav a[data-controller~='ui--active-link']")

    expect(rows).to be_present
    expect(component).to have_no_css "nav a[aria-current]"

    search = rows.find { |row| row.text.strip == "Search Registrations" }
    expect(search["data-ui--active-link-match-value"]).to eq "controller_action"
    expect(search["data-ui--active-link-routes-value"]).to eq "organized/registrations#index"

    sequences = rows.find { |row| row.text.strip == "Manage Registration sequences" }
    expect(sequences["data-ui--active-link-match-value"]).to eq "controller"
    expect(sequences["data-ui--active-link-routes-value"])
      .to eq "organized/registration_sequences organized/registration_sequence_pages"
  end

  # Both point at organized/bikes#new, so only the query string tells them apart
  it "matches the two add-a-bike rows on their full path" do
    rows = component.css("nav a[data-ui--active-link-match-value='full_path']")

    expect(rows.map { |row| row["href"] })
      .to eq(["/o/#{organization.to_param}/bikes/new",
        "/o/#{organization.to_param}/bikes/new?parking_notification=true"])
  end

  # Which group holds the current page is the browser's to say, so the server opens the
  # first one -- the design's default for a page no row matches
  it "opens the first group and no other" do
    expect(component.css("[aria-controls^='org_sidebar_group_'][aria-expanded='true']")
      .map { |button| button.text.strip }).to eq(["Brakebills Registrations"])

    closed = component.css("[data-ui--collapse-target='content']").drop(1)
    expect(closed.map { |content| content["class"] }).to all(include("tw:hidden!"))
  end

  context "with an ambassador organization" do
    let(:organization) { FactoryBot.create(:organization_ambassador, short_name: "Fillory") }

    it "renders the ambassador's flat rows, with no group to open" do
      expect(component).to have_no_css "[aria-controls^='org_sidebar_group_']"
      expect(component.css("nav a[href^='/o/'], nav a[href^='https://discuss']").map(&:text).map(&:strip))
        .to eq(["Fillory Dashboard", "Resources", "Getting started", "Multi search", "Discuss"])
    end
  end

  context "without an organization" do
    let(:instance) { described_class.new(organization: nil, current_user:) }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end

  context "without a current_user" do
    let(:instance) { described_class.new(organization:, current_user: nil) }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
