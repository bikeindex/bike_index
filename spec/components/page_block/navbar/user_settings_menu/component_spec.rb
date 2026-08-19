# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::UserSettingsMenu::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed, email: "party@bikeindex.org") }
  let(:dropdown) { false }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user, dropdown:,
      name: "Settings")
  end
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:links) { component.css("a").map { |link| link.text.strip } }

  it "renders the navbar's gear and its own list" do
    expect(component).to have_css "#setting_submenu"
    expect(component).to have_css "ul.primary-submenu"
    expect(links).to eq(["Your registrations", "Register a new bike", "party@bikeindex.org settings", "Log out"])
    expect(component).to have_css "#navUserSettingLink[data-email='party@bikeindex.org']"
    # The submenu's rows are the navbar's own links, so they take .nav-link with the rest
    expect(component.css("ul.primary-submenu a.nav-link").count).to eq links.count
  end

  context "with dropdown" do
    let(:dropdown) { true }

    # The sidebar hangs it off the account block at the foot of the column, so it reads
    # outward from there -- the navbar's order, inverted
    it "renders the account links as dropdown entries, in the other order" do
      expect(component).to have_css "button#settings[data-ui--dropdown-target='button']"
      expect(component).to have_no_css "ul.primary-submenu"
      expect(component.css("ul[role='menu'] a").map { |link| link.text.strip })
        .to eq(["Log out", "party@bikeindex.org settings", "Register a new bike", "Your registrations"])
      expect(component).to have_css "#navUserSettingLink[data-email='party@bikeindex.org']"
    end
  end

  # Which row is current is ui--active-link's, in the browser -- the navbar renders inside a
  # fragment cache, so it can't carry the answer for whichever page filled it
  it "hands every row to UI::ActiveLink to resolve" do
    rows = component.css("a[data-controller~='ui--active-link']")

    expect(rows.map { |row| row.text.strip }).to eq(links)
    expect(component).to have_no_css "a[aria-current]"
    expect(rows.map { |row| row["data-ui--active-link-match-value"] }).to all(eq("path"))
  end

  # Logging out is the only row that doesn't go somewhere, so it's the only one in red
  it "marks logout in both renderings" do
    expect(component.css("a[class*='text-red']").map { |link| link.text.strip }).to eq(["Log out"])

    with_dropdown = with_request_url("/") do
      render_inline(described_class.new(current_user:, current_user_or_unconfirmed_user: current_user,
        dropdown: true, name: "Settings"))
    end
    expect(with_dropdown.css("a[class*='text-red']").map { |link| link.text.strip }).to eq(["Log out"])
  end

  context "with a marketplace message" do
    let!(:marketplace_message) { FactoryBot.create(:marketplace_message, sender: current_user) }

    it "adds the marketplace messages link" do
      expect(component).to have_css "a[href='/my_account/messages']", text: "Marketplace messages"
    end
  end

  context "with an organization role" do
    let(:organization) { FactoryBot.create(:organization, name: "Sweet Shop") }
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }

    # Its own section between the account rows and logout, set off on both sides
    it "links to the organization between the dividers" do
      expect(links).to eq(["Your registrations", "Register a new bike",
        "party@bikeindex.org settings", "Switch to Sweet Shop", "Log out"])
      expect(component.css("ul.primary-submenu li.divider-nav-item").count).to eq 2
    end

    # It's the page they're on, so the row is a label rather than a link
    context "viewing that organization" do
      let(:instance) do
        described_class.new(current_user:, current_user_or_unconfirmed_user: current_user,
          dropdown: false, current_organization: organization)
      end

      it "renders it disabled" do
        expect(links).to_not include("Switch to Sweet Shop")
        expect(component.css("ul.primary-submenu span").map { |span| span.text.strip })
          .to eq(["Viewing Sweet Shop"])
      end
    end
  end

  context "with an unconfirmed user" do
    let(:unconfirmed_user) { FactoryBot.create(:user) }
    let(:instance) do
      described_class.new(current_user: nil, current_user_or_unconfirmed_user: unconfirmed_user,
        dropdown: false, name: "Settings")
    end

    it "renders their settings and logout" do
      expect(links).to eq(["Your registrations", "Register a new bike", "#{unconfirmed_user.email} settings", "Log out"])
    end
  end
end
