# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::UserSettingsMenu::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed, email: "party@bikeindex.org") }
  let(:instance) { described_class.new(current_user:, current_user_or_unconfirmed_user: current_user) }
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:links) { component.css("a").map { |link| link.text.strip } }

  it "renders the gear and its own list" do
    expect(component).to have_css "#setting_submenu"
    expect(component).to have_css "ul.primary-submenu"
    expect(links).to eq(["Your registrations", "Register a new bike", "party@bikeindex.org settings", "Log out"])
    expect(component).to have_css "#navUserSettingLink[data-email='party@bikeindex.org']"
    # The submenu's rows are the navbar's own links, so they take .nav-link with the rest
    expect(component.css("ul.primary-submenu a.nav-link").count).to eq links.count
  end

  # Which row is current is ui--active-link's, in the browser -- the navbar renders inside a
  # fragment cache, so it can't carry the answer for whichever page filled it
  it "hands every row to UI::ActiveLink to resolve" do
    rows = component.css("a[data-controller~='ui--active-link']")

    expect(rows.map { |row| row.text.strip }).to eq(links)
    expect(component).to have_no_css "a[aria-current]"
    expect(rows.map { |row| row["data-ui--active-link-match-value"] }).to all(eq("path"))
  end

  # Logging out is the only row that doesn't go somewhere, so it's the only one tinted
  it "marks logout" do
    expect(component.css("a[class*='text-red']").map { |link| link.text.strip }).to eq(["Log out"])
  end

  # The rows beyond its own are UserServices::MenuItemsAccount's, which its own spec covers --
  # this is that they reach the menu, in its order
  context "with an organization role" do
    let(:organization) { FactoryBot.create(:organization, name: "Sweet Shop") }
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }

    it "links to the organization between the dividers" do
      expect(links).to eq(["Your registrations", "Register a new bike",
        "party@bikeindex.org settings", "Switch to Sweet Shop", "Log out"])
      expect(component.css("ul.primary-submenu li.divider-nav-item").count).to eq 2
    end
  end

  context "with an unconfirmed user" do
    let(:unconfirmed_user) { FactoryBot.create(:user) }
    let(:instance) do
      described_class.new(current_user: nil, current_user_or_unconfirmed_user: unconfirmed_user)
    end

    it "renders their settings and logout" do
      expect(links).to eq(["Your registrations", "Register a new bike", "#{unconfirmed_user.email} settings", "Log out"])
    end
  end
end
