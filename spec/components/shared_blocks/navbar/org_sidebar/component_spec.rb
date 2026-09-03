# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Navbar::OrgSidebar::Component, type: :component do
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

    # The sidebar stands in for the navbar, so it carries the account menu too -- whose rows
    # are SharedBlocks::Navbar::AccountMenu's spec's, not this one's
    expect(component).to have_css "button[data-ui--dropdown-target='button']", text: "kdewey@brakebills.edu"
    # Brakebills is the organization it's the sidebar for, so its row has nowhere to go
    expect(component.css("ul[role='menu'] li[role='menuitem'] span").map(&:text))
      .to eq(["Viewing Brakebills"])
  end

  # The switcher and the messages row are UserServices::MenuItemsAccount's, which its own
  # spec covers -- this is that they reach the menu
  context "with a marketplace message" do
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let!(:marketplace_message) do
      FactoryBot.create(:marketplace_message, marketplace_listing:, sender: current_user)
    end

    it "reaches the messages from the account menu" do
      expect(component.css("ul[role='menu'] li[role='menuitem'] a").map(&:text))
        .to include("Marketplace messages")
    end
  end

  # Which row is current is ui--active-link's, in the browser, so every row states what
  # it takes to be the page it points at rather than whether it is one
  it "hands each row to UI::ActiveLink to resolve" do
    rows = component.css("nav a[data-controller~='ui--active-link']")

    expect(rows).to be_present
    expect(component).to have_no_css "nav a[aria-current]"

    search = rows.find { |row| row.text.strip == "Search Registrations" }
    expect(search["data-ui--active-link-match-paths-value"])
      .to eq "/o/#{organization.to_param}/registrations"

    # Editing a page of a sequence is its own path, off the sequences one
    sequences = rows.find { |row| row.text.strip == "Registration sequences" }
    expect(sequences["data-ui--active-link-match-paths-value"])
      .to eq "/o/#{organization.to_param}/registration_sequences/** " \
        "/o/#{organization.to_param}/registration_sequence_pages/**"
  end

  # The old view puts both rows on organized/bikes#new, so the param tells them apart
  it "matches the two add-a-bike rows on the param" do
    rows = component.css("nav a[data-ui--active-link-match-params-value*='parking_notification']")

    expect(rows.map { |row| row["href"] })
      .to eq(["/o/#{organization.to_param}/registrations/new",
        "/o/#{organization.to_param}/bikes/new?parking_notification=true"])
    expect(rows.map { |row| row["data-ui--active-link-match-params-value"] })
      .to eq([{parking_notification: [""]}.to_json, {parking_notification: ["true"]}.to_json])
  end

  # Which group holds the current page is the browser's to say, so the server opens the
  # first one -- the design's default for a page no row matches
  it "opens the first group and no other" do
    expect(component.css("[aria-controls^='org_sidebar_group_'][aria-expanded='true']")
      .map { |button| button.text.strip }).to eq(["Brakebills Registrations"])

    closed = component.css("[data-ui--collapse-target='content']").drop(1)
    expect(closed.map { |content| content["class"] }).to all(include("tw:hidden!"))
  end

  # It's the only row that isn't the organization's own, so it sits after them all
  context "with a superuser" do
    let(:current_user) { FactoryBot.create(:superuser, email: "kdewey@brakebills.edu") }

    it "ends with the super admin link" do
      rows = component.css("[data-shared-blocks--org-sidebar-target='scroller'] a")

      expect(rows.last["href"]).to eq "/admin/organizations/#{organization.to_param}"
      # It renders through the ordinary icon branch, with no special case of its own
      expect(rows.last.css("svg").count).to eq 1
    end

    # They reach the organization without being a member of it
    context "in no organization" do
      let!(:organization_role) { nil }

      it "still carries the switcher's rows" do
        expect(component.css("ul[role='menu'] li[role='menuitem'] a").map(&:text))
          .to include("View without any organization")
        expect(component.css("ul[role='menu'] li[role='menuitem'] span").map(&:text))
          .to eq(["Viewing Brakebills"])
      end
    end
  end

  context "with an ambassador organization" do
    let(:organization) { FactoryBot.create(:organization_ambassador, short_name: "Fillory") }

    it "renders the ambassador's flat rows, with no group to open" do
      expect(component).to have_no_css "[aria-controls^='org_sidebar_group_']"
      # The scroller holds the menu rows; the account menu below it has its own /o/ links
      expect(component.css("[data-shared-blocks--org-sidebar-target='scroller'] a").map(&:text).map(&:strip))
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
