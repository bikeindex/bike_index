# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::UserSettingsMenu::Component, type: :component do
  let(:current_user) { FactoryBot.create(:user_confirmed, email: "party@bikeindex.org") }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user, name: "Settings")
  end
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:links) { component.css("ul[role='menu'] a").map { |link| link.text.strip } }

  it "renders the account links as dropdown entries" do
    expect(component).to have_css "button#settings[data-ui--dropdown-target='button']"
    expect(links).to eq(["Your registrations", "Register a new bike", "party@bikeindex.org settings", "Log out"])
    expect(component).to have_css "#navUserSettingLink[data-email='party@bikeindex.org']"
    # Logging out is the only row that doesn't go somewhere, so it's the only one in red
    expect(component.css("a[class]").map(&:text)).to eq(["Log out"])
  end

  context "with a marketplace message" do
    let!(:marketplace_message) { FactoryBot.create(:marketplace_message, sender: current_user) }

    it "adds the marketplace messages link" do
      expect(component).to have_css "ul[role='menu'] a[href='/my_account/messages']", text: "Marketplace messages"
    end
  end

  context "with an organization role" do
    let(:organization) { FactoryBot.create(:organization, name: "Sweet Shop") }
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }

    it "links to the organization above a divider" do
      expect(links.first).to eq "Switch to Sweet Shop admin"
      expect(component).to have_css "ul[role='menu'] li[role='separator']"
    end
  end

  context "with an unconfirmed user" do
    let(:unconfirmed_user) { FactoryBot.create(:user) }
    let(:instance) do
      described_class.new(current_user: nil, current_user_or_unconfirmed_user: unconfirmed_user, name: "Settings")
    end

    it "renders their settings and logout" do
      expect(links).to eq(["Your registrations", "Register a new bike", "#{unconfirmed_user.email} settings", "Log out"])
    end
  end
end
