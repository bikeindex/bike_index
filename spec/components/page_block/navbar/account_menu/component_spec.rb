# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::AccountMenu::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed, email: "party@bikeindex.org") }
  let(:current_organization) { nil }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user,
      current_organization:)
  end
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:links) { component.css("ul[role='menu'] a").map { |link| link.text.strip } }

  # It hangs off the account block at the foot of the sidebar, so it reads outward from
  # there -- PageBlock::Navbar::UserSettingsMenu's order, inverted
  it "renders the rows as dropdown entries, opening upward" do
    expect(component).to have_css "button[data-ui--dropdown-target='button']"
    expect(component).to have_no_css "ul.primary-submenu"
    expect(links).to eq(["Log out", "party@bikeindex.org settings", "Register a new bike",
      "Your registrations"])
    expect(component).to have_css "#navUserSettingLink[data-email='party@bikeindex.org']"
  end

  # .twdropdown styles every other entry, so logout is the only one carrying a class
  it "marks logout, and leaves the rest to .twdropdown" do
    expect(component.css("ul[role='menu'] a[class]").map { |link| link.text.strip }).to eq(["Log out"])
    expect(component.css("ul[role='menu'] a[class*='text-red']").count).to eq 1
  end

  it "hands every row to UI::ActiveLink to resolve" do
    expect(component.css("ul[role='menu'] a[data-controller~='ui--active-link']").count).to eq links.count
    expect(component).to have_no_css "a[aria-current]"
  end

  context "viewing an organization" do
    let(:current_organization) { FactoryBot.create(:organization, name: "Sweet Shop") }
    let!(:organization_role) do
      FactoryBot.create(:organization_role_claimed, user: current_user, organization: current_organization)
    end

    # It's where they already are, so the row for it is a label rather than a link
    it "labels the one being viewed and links out of it" do
      expect(links).to include("View without any organization")
      expect(links).to_not include("Switch to Sweet Shop")
      expect(component.css("ul[role='menu'] span[data-active='true']").map { |span| span.text.strip })
        .to eq(["Viewing Sweet Shop"])
    end
  end
end
