# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::PrimaryMenu::Component, type: :component do
  let(:current_user) { nil }
  let(:instance) do
    described_class.new(current_user_or_unconfirmed_user: current_user)
  end
  let(:component) { render_inline(instance) }
  let(:menu_links) { component.css("#primary-main-menu a").map { |link| link.text.strip } }

  def links_named(label) = component.css("#primary-main-menu a").select { |link| link.text.strip == label }

  it "renders the signed out menu, with every item's state left to the browser" do
    expect(menu_links).to eq(["Search", "Marketplace", "Sign up", "log in", "Help",
      "Stolen bike?", "Donate", "Blog", "Marketplace", "Search"])
    expect(component).to_not have_css "#setting_submenu"
    expect(component).to_not have_css "#primary-main-menu a[aria-current]"
    expect(component.css("#primary-main-menu a[data-controller='ui--active-link']").count).to eq menu_links.count
    # Every row is a nav-link; only the signup one carries a second class
    expect(component.css("#primary-main-menu a.nav-link").count).to eq menu_links.count
    expect(component.css("#primary-main-menu a.signup-link").map { |link| link.text.strip }).to eq(["Sign up"])
  end

  # The links carry a stolenness the page won't, and the page carries a query and a page
  # number they don't, so naming no params is what keeps them active across the search
  it "covers the search and marketplace pages whatever they're filtered by" do
    expect(links_named("Search").map { |link| link["data-ui--active-link-match-paths-value"] })
      .to eq(["/search/registrations"] * 2)
    expect(links_named("Search").map { |link| link["data-ui--active-link-match-params-value"] })
      .to eq([nil] * 2)
    expect(links_named("Marketplace").map { |link| link["data-ui--active-link-match-paths-value"] })
      .to eq(["/search/marketplace"] * 2)
    expect(links_named("Blog").map { |link| link["data-ui--active-link-match-paths-value"] })
      .to eq(["/news/**"])
  end

  context "with a current_user" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "renders the settings menu rather than the sign up links" do
      expect(component).to have_css "li.primary-nav-item #setting_submenu"
      expect(menu_links).to_not include("Sign up", "log in")
    end
  end
end
