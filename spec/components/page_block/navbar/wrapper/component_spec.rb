# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::Wrapper::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:current_user) { nil }
  let(:instance) { described_class.new(current_user:, current_user_or_unconfirmed_user: current_user) }
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
      expect(instance.org_sidebar?).to be false
    end

    # The sidebar stands in for the whole bar, so this renders one or the other
    context "with a passive_organization" do
      let(:organization) { FactoryBot.create(:organization, short_name: "Sweet") }
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }
      let(:instance) do
        described_class.new(current_user:, current_user_or_unconfirmed_user: current_user,
          passive_organization: organization)
      end

      it "renders the sidebar in place of the navbar" do
        expect(instance.org_sidebar?).to be true
        expect(component).to have_css "nav#org_sidebar_nav", text: "Sweet"
        expect(component).to have_no_css "nav.primary-header-nav"
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
  end
end
