# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::PrimaryMenu::Component, type: :component do
  let(:current_user) { nil }
  let(:instance) { described_class.new(current_user:, current_user_or_unconfirmed_user: current_user) }
  let(:component) { render_inline(instance) }
  let(:menu_links) { component.css("#primary-main-menu a").map { |link| link.text.strip } }
  let(:labels_for) { ->(selector) { component.css(selector).map { |link| link.text.strip } } }

  it "renders the signed out menu, with every link's active rule but no answer" do
    expect(menu_links).to eq(["Search", "Marketplace", "Sign up", "log in", "Help",
      "Stolen bike?", "Donate", "Blog", "Marketplace", "Search"])
    expect(component).to_not have_css "#setting_submenu"
    expect(component).to_not have_css "#primary-main-menu a.active"
    # Both search links stay active across their whole controller, whatever the rider narrowed to
    expect(labels_for.call("a[data-active-routes='search/registrations']")).to eq %w[Search Search]
    expect(labels_for.call("a[data-active-routes='search/marketplace']")).to eq %w[Marketplace Marketplace]
    expect(labels_for.call("a[data-active-routes='news']")).to eq %w[Blog]
    expect(labels_for.call("a[data-active-path]")).to eq ["Sign up", "log in", "Help", "Stolen bike?", "Donate"]
  end

  context "with a current_user" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "renders the settings menu rather than the sign up links" do
      expect(component).to have_css "li.primary-nav-item #setting_submenu"
      expect(menu_links).to_not include("Sign up", "log in")
    end
  end
end
