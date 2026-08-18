# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::PrimaryMenu::Component, type: :component do
  let(:current_user) { nil }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user)
  end
  let(:component) { render_inline(instance) }
  let(:menu_links) { component.css("#primary-main-menu a").map { |link| link.text.strip } }

  def links_named(label) = component.css("#primary-main-menu a").select { |link| link.text.strip == label }

  it "renders the signed out menu, with every item's state left to the browser" do
    expect(menu_links).to eq(["Search", "Marketplace", "Sign up", "log in", "Help",
      "Stolen bike?", "Donate", "Blog", "Marketplace", "Search"])
    expect(component).to_not have_css "#setting_submenu"
    expect(component).to_not have_css "#primary-main-menu a.active"
    expect(component.css("#primary-main-menu a[data-controller='ui--active-link']").count).to eq menu_links.count
  end

  # The links carry a stolenness the page won't, and the page carries a query and a page
  # number they don't, so the route is what matches
  it "matches the search and marketplace links on their route" do
    expect(links_named("Search").map { |link| link["data-ui--active-link-route-value"] })
      .to eq(["search/registrations#index"] * 2)
    expect(links_named("Marketplace").map { |link| link["data-ui--active-link-route-value"] })
      .to eq(["search/marketplace#index"] * 2)
    expect(links_named("Blog").map { |link| link["data-ui--active-link-match-value"] })
      .to eq(["controller"])
  end

  context "with a current_user" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "renders the settings menu rather than the sign up links" do
      expect(component).to have_css "li.primary-nav-item #setting_submenu"
      expect(menu_links).to_not include("Sign up", "log in")
    end
  end
end
