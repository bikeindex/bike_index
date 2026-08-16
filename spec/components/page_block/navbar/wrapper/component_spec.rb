# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::Wrapper::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:current_user) { nil }
  let(:passive_organization) { nil }
  let(:controller_namespace) { nil }
  let(:controller_name) { "welcome" }
  let(:action_name) { "index" }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user, passive_organization:,
      controller_namespace:, controller_name:, action_name:)
  end
  let(:component) { render_inline(instance) }

  it "renders the logo, the primary menu and the signed out signup link" do
    expect(component).to have_css "nav.primary-header-nav a.primary-logo"
    expect(component).to have_css ".nonprofit-subtitle"
    expect(component).to have_css "a.center-navbar-signup-link", text: "Sign up"
    expect(component).to have_css "#primary-main-menu"
    expect(component).to_not have_css "#passive_organization_submenu"
  end

  context "with a current_user" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "drops the signup link without adding an organization menu" do
      expect(component).to_not have_css "a.center-navbar-signup-link"
      expect(component).to_not have_css "#passive_organization_submenu"
      expect(component).to have_css "#setting_submenu"
    end

    context "with a passive_organization" do
      let(:passive_organization) { FactoryBot.create(:organization, short_name: "Sweet") }

      it "renders the organization menu" do
        expect(component).to have_css "#passive_organization_submenu", text: "Sweet"
        expect(component).to have_css ".current-organization-submenu a"
      end
    end
  end

  context "with logo_only" do
    let(:instance) { described_class.new(logo_only: true) }

    it "renders the logo without the menus" do
      expect(component).to have_css "nav.primary-header-nav a.primary-logo"
      expect(component).to_not have_css "#primary-main-menu"
      expect(component).to_not have_css ".hamburgler"
      expect(component).to_not have_css ".nonprofit-subtitle"
    end
  end

  describe "caching", :caching do
    include_context :caching_basic

    # The cached fragment must include the locale in its key, or a request in
    # one language serves the navbar cached in another. See ApplicationComponentHelper#cache.
    it "varies the cached fragment by locale" do
      en = render_inline(instance).to_html
      nl = I18n.with_locale(:nl) { render_inline(instance) }.to_html
      expect(en).to include("Stolen bike?")
      expect(nl).to_not include("Stolen bike?")
    end

    context "with a passive_organization the org dashboard link is injected for" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: passive_organization) }
      let(:passive_organization) { FactoryBot.create(:organization, short_name: "Sweet") }
      let(:dashboard_label) { "Sweet dashboard" }

      # Every other page shares one entry, so the injected link has to key it too
      it "keeps the dashboard override out of the navbar cached elsewhere" do
        on_dashboard = render_inline(described_class.new(current_user:,
          current_user_or_unconfirmed_user: current_user, passive_organization:,
          controller_namespace: "organized", controller_name: "dashboard", action_name: "index")).to_html
        expect(passive_organization.overview_dashboard?).to be false
        expect(on_dashboard).to include(dashboard_label)
        expect(component.to_html).to_not include(dashboard_label)
      end
    end
  end
end
