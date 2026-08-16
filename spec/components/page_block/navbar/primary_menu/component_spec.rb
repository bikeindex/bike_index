# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::PrimaryMenu::Component, type: :component do
  let(:current_user) { nil }
  let(:controller_namespace) { nil }
  let(:controller_name) { "welcome" }
  let(:action_name) { "index" }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user,
      controller_namespace:, controller_name:, action_name:)
  end
  # The request drives UI::ActiveLink, which resolves the items that pass no :active
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:menu_links) { component.css("#primary-main-menu a").map { |link| link.text.strip } }

  it "renders the signed out menu" do
    expect(menu_links).to eq(["Search", "Marketplace", "Sign up", "log in", "Help",
      "Stolen bike?", "Donate", "Blog", "Marketplace", "Search"])
    expect(component).to_not have_css "#setting_submenu"
    expect(component).to_not have_css "#primary-main-menu a.active"
  end

  context "on the registration search page" do
    let(:controller_namespace) { "search" }
    let(:controller_name) { "registrations" }

    it "marks both registration search links active" do
      expect(component.css("#primary-main-menu a.active").map { |link| link.text.strip }).to eq(%w[Search Search])
    end
  end

  context "on the marketplace search page" do
    let(:controller_namespace) { "search" }
    let(:controller_name) { "marketplace" }

    it "marks both marketplace links active" do
      expect(component.css("#primary-main-menu a.active").map { |link| link.text.strip }).to eq(%w[Marketplace Marketplace])
    end
  end

  context "with a current_user" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "renders the settings menu rather than the sign up links" do
      expect(component).to have_css "li.primary-nav-item #setting_submenu"
      expect(menu_links).to_not include("Sign up", "log in")
    end
  end
end
