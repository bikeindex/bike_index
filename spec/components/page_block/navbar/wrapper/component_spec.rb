# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::Wrapper::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:current_user) { nil }
  let(:passive_organization) { nil }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user, passive_organization:,
      controller_namespace: nil, controller_name: "welcome", action_name: "index")
  end
  let(:component) { with_request_url("/") { render_inline(instance) } }

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
      en = with_request_url("/") { render_inline(instance) }.to_html
      nl = I18n.with_locale(:nl) { with_request_url("/") { render_inline(instance) } }.to_html
      expect(en).to include("Stolen bike?")
      expect(nl).to_not include("Stolen bike?")
    end

    # The organization menu renders outside the cache, so the link it re-adds on its own
    # page isn't served to every other page from a fragment cached on one of them
    context "with an organization lacking the bulk imports feature" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: passive_organization) }
      let(:passive_organization) { FactoryBot.create(:organization) }
      let(:on_bulk_imports) do
        described_class.new(current_user:, current_user_or_unconfirmed_user: current_user,
          passive_organization:, controller_namespace: "organized", controller_name: "bulk_imports",
          action_name: "index")
      end

      it "re-adds its link on the bulk imports page, having cached another page first" do
        expect(passive_organization.show_bulk_import?).to be false
        expect(component).to_not have_css ".current-organization-submenu a", text: "Bulk Imports"

        rendered = with_request_url("/o/#{passive_organization.to_param}/bulk_imports") do
          render_inline(on_bulk_imports)
        end
        expect(rendered).to have_css ".current-organization-submenu a", text: "Bulk Imports"
        expect(rendered).to have_css "#primary-main-menu"
      end
    end
  end
end
