# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::PrimaryMenu::Component, type: :component do
  let(:current_user) { nil }
  let(:request_url) { "/" }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user)
  end
  # The request drives UI::ActiveLink, which resolves every item that passes no :active
  let(:component) { with_request_url(request_url) { render_inline(instance) } }
  let(:menu_links) { component.css("#primary-main-menu a").map { |link| link.text.strip } }

  it "renders the signed out menu" do
    expect(menu_links).to eq(["Search", "Marketplace", "Sign up", "log in", "Help",
      "Stolen bike?", "Donate", "Blog", "Marketplace", "Search"])
    expect(component).to_not have_css "#setting_submenu"
    expect(component).to_not have_css "#primary-main-menu a[aria-current]"
  end

  # The links carry query params the page won't, which is why they match on controller and action
  context "on the registration search page" do
    let(:request_url) { "/search/registrations?query=trek" }

    it "marks both registration search links active" do
      expect(component.css("#primary-main-menu a[aria-current]").map { |link| link.text.strip }).to eq(%w[Search Search])
    end

    context "on page 2" do
      let(:request_url) { "/search/registrations?stolenness=all&page=2" }

      it "marks them active" do
        expect(component.css("#primary-main-menu a[aria-current]").map { |link| link.text.strip }).to eq(%w[Search Search])
      end
    end

    # The link points at stolenness=all, but every stolenness is the same search page
    context "searching a different stolenness" do
      let(:request_url) { "/search/registrations?stolenness=stolen" }

      it "marks them active" do
        expect(component.css("#primary-main-menu a[aria-current]").map { |link| link.text.strip }).to eq(%w[Search Search])
      end
    end
  end

  context "on the marketplace search page" do
    let(:request_url) { "/search/marketplace" }

    it "marks both marketplace links active" do
      expect(component.css("#primary-main-menu a[aria-current]").map { |link| link.text.strip }).to eq(%w[Marketplace Marketplace])
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
