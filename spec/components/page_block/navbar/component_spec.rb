# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:current_user) { nil }
  let(:passive_organization) { nil }
  let(:url) { "/" }
  let(:instance) do
    described_class.new(current_user:, current_user_or_unconfirmed_user: current_user,
      passive_organization:, page_id: "welcome_index")
  end
  let(:component) { with_request_url(url) { render_inline(instance) } }
  let(:menu_links) { component.css("#primary-main-menu a").map { |link| link.text.strip } }

  it "renders the signed out menu" do
    expect(component).to have_css "nav.primary-header-nav"
    expect(component).to have_css "a.center-navbar-signup-link", text: "Sign up"
    expect(menu_links).to eq(["Search", "Marketplace", "Sign up", "log in", "Help",
      "Stolen bike?", "Donate", "Blog", "Marketplace", "Search"])
    expect(component).to_not have_css "#setting_submenu"
    expect(component).to_not have_css "#primary-main-menu a.active"
  end

  context "on the registration search page" do
    let(:url) { "/search/registrations?stolenness=all" }

    it "marks both registration search links active" do
      expect(component.css("#primary-main-menu a.active").map { |link| link.text.strip }).to eq(%w[Search Search])
    end
  end

  context "on the marketplace search page" do
    let(:url) { "/search/marketplace" }

    it "marks both marketplace links active" do
      expect(component.css("#primary-main-menu a.active").map { |link| link.text.strip }).to eq(%w[Marketplace Marketplace])
    end
  end

  context "with a current_user" do
    let(:current_user) { FactoryBot.create(:user_confirmed, email: "party@bikeindex.org") }

    it "renders the settings submenu rather than the sign up links" do
      expect(component).to have_css "#setting_submenu"
      expect(component).to_not have_css "a.center-navbar-signup-link"
      expect(component.css(".primary-submenu a").map { |link| link.text.strip })
        .to eq(["Your registrations", "Register a new bike", "party@bikeindex.org settings", "Logout"])
      expect(component).to have_css "#navUserSettingLink[data-email='party@bikeindex.org']"
    end

    context "with a marketplace message" do
      let!(:marketplace_message) { FactoryBot.create(:marketplace_message, sender: current_user) }

      it "adds the marketplace messages link" do
        expect(component).to have_css ".primary-submenu a[href='/my_account/messages']", text: "Marketplace messages"
      end
    end

    context "with an organization role" do
      let(:organization) { FactoryBot.create(:organization, name: "Sweet Shop", short_name: "Sweet") }
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }

      it "links to the organization from the settings submenu" do
        expect(component).to have_css ".primary-submenu a", text: "View Sweet Shop"
      end

      context "with a passive_organization" do
        let(:passive_organization) { organization }

        it "renders the organization submenu" do
          expect(component).to have_css "#passive_organization_submenu", text: "Sweet"
          expect(component).to have_css ".current-organization-submenu a"
        end
      end
    end
  end

  context "with logo_only" do
    let(:instance) { described_class.new(logo_only: true) }

    it "renders the logo without the menu" do
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
      en = with_request_url(url) { render_inline(instance) }.to_html
      nl = I18n.with_locale(:nl) { with_request_url(url) { render_inline(instance) } }.to_html
      expect(en).to include("Stolen bike?")
      expect(nl).to_not include("Stolen bike?")
    end
  end
end
