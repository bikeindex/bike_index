# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Navbar::Component, type: :component do
  let(:admin_bikes) { "/admin/bikes" }
  # Somewhere outside admin, so no nav link is the active one
  let(:url) { "/bikes/new" }
  let(:current_user) { FactoryBot.create(:superuser) }
  let(:search_filtered) { false }
  let(:instance) do
    described_class.new(current_user:, user_root_url: "/admin", search_filtered:)
  end
  let(:component) { with_request_url(url) { render_inline(instance) } }
  # The picker's "All" link
  let(:view_all_link) { "a.text-muted" }

  it "renders the shortcut links and an option per admin page, minus the dev pages" do
    expect(component.css("ul.navbar-nav a").map(&:text)).to eq(%w[Users Bikes Organizations News Stolen])
    expect(component).to have_css("[data-controller='admin--navbar'][data-action='hw-combobox:selection->admin--navbar#navigate']")
    expect(component).to have_css("[role='option'][data-value='#{admin_bikes}']", text: "Bikes", visible: :all)
    expect(component).to have_css("[role='option'][data-value='/admin/organizations']", text: "Organizations", visible: :all)
    expect(component).to_not have_css("[role='option'][data-value='/admin/feature_flags']", visible: :all)
    expect(component).to have_css("input[role='combobox'][placeholder='Admin navigation']")
    expect(component).to_not have_css(view_all_link)
  end

  context "with a developer" do
    let(:current_user) { FactoryBot.create(:superuser_developer) }

    it "adds the dev pages, sorted in among the rest" do
      expect(component).to have_css("[role='option'][data-value='/admin/feature_flags']", text: "Dev: Feature Flags", visible: :all)
      expect(component.css("[role='option']").map(&:text)).to eq component.css("[role='option']").map(&:text).sort
    end
  end

  context "with a non-superuser" do
    let(:current_user) { FactoryBot.create(:user) }

    it "renders only the brand and the exit link" do
      expect(component).to have_css("a", text: "Exit Admin")
      expect(component).to_not have_css("[role='option']", visible: :all)
      expect(component).to_not have_css("ul.navbar-nav")
    end
  end

  describe "the shortcut links" do
    let(:shortcuts) { component.css("ul.navbar-nav a[data-controller='ui--active-link']") }

    # The shortcuts take what they cover from nav_select_links, so they stay active across a
    # section rather than only on its index. UI::ActiveLink resolves that in the browser,
    # against the patterns rendered here -- organizations#recover being routed outside its own.
    it "covers each shortcut's whole section" do
      expect(shortcuts.map { |link| link["data-ui--active-link-match-paths-value"] })
        .to eq(["/admin/users/**", "/admin/bikes/**",
          "/admin/organizations/** /admin/recover_organization",
          "/admin/news/**", "/admin/stolen_bikes/**"])
    end
  end

  describe "the view all link" do
    context "period all" do
      let(:url) { "#{admin_bikes}?period=all&timezone=Party" }

      it "names the active page, without a view all link" do
        expect(component).to have_css("input[role='combobox'][placeholder='Viewing Bikes']")
        expect(component).to_not have_css(view_all_link)
      end
    end

    context "with sort" do
      let(:url) { "#{admin_bikes}?direction=desc&render_chart=true&sort=manufacturer_id" }

      it "renders no view all link" do
        expect(component).to_not have_css(view_all_link)
      end
    end

    context "with period != all" do
      let(:url) { "#{admin_bikes}?period=week&timezone=Party" }
      let(:search_filtered) { true }

      it "links to the unfiltered page" do
        expect(component).to have_css("#{view_all_link}[href='#{admin_bikes}']", text: /All\s+Bikes/)
      end
    end

    context "with a search param" do
      let(:url) { "#{admin_bikes}?search_email=party@example.com" }
      let(:search_filtered) { true }

      it "links to the unfiltered page" do
        expect(component).to have_css("#{view_all_link}[href='#{admin_bikes}']", text: /All\s+Bikes/)
      end
    end

    context "on another page of the same controller" do
      let(:url) { "#{admin_bikes}/duplicates" }

      it "links to the unfiltered page" do
        expect(component).to have_css("#{view_all_link}[href='#{admin_bikes}']", text: /All\s+Bikes/)
      end
    end

    context "on a Config: page" do
      let(:url) { "/admin/email_domains?search_status=banned" }
      let(:search_filtered) { true }

      it "drops the prefix from the title" do
        expect(component).to have_css("#{view_all_link}[href='/admin/email_domains']", text: /All\s+Email Domains/)
      end
    end

    # Nested under organizations, which the invoices entry names in a pattern of its own
    context "on an organization's invoices" do
      let(:url) { "/admin/organizations/bike-shop/invoices" }

      it "names the section itself, and links to every invoice" do
        expect(component).to have_css("input[role='combobox'][placeholder='Viewing Invoices']")
        expect(component).to have_css("#{view_all_link}[href^='/admin/invoices']", text: /All\s+Invoices/)
      end
    end

    context "on an organization's custom layouts" do
      let(:url) { "/admin/organizations/bike-shop/custom_layouts" }

      # There is no admin index of custom layouts to be "all" of, so it falls back to the
      # section it's nested under rather than naming nothing
      it "falls back to the organizations it's nested under" do
        expect(component).to have_css("input[role='combobox'][placeholder='Viewing Organizations']")
        expect(component).to have_css("#{view_all_link}[href='/admin/organizations']", text: /All\s+Organizations/)
      end

      context "editing the landing page" do
        let(:current_user) { FactoryBot.create(:superuser_developer) }
        let(:url) { "/admin/organizations/bike-shop/custom_layouts/landing_page/edit" }

        it "names the landing pages, and links to every one" do
          expect(component).to have_css("input[role='combobox'][placeholder='Viewing Dev: Organization Landing Pages']")
          expect(component).to have_css("#{view_all_link}[href='/admin/organization_landing_pages']",
            text: /All\s+Organization Landing Pages/)
        end
      end

      context "editing a mail snippet" do
        let(:url) { "/admin/organizations/bike-shop/custom_layouts/welcome_email/edit" }

        it "falls back to the organizations it's nested under" do
          expect(component).to have_css("#{view_all_link}[href='/admin/organizations']", text: /All\s+Organizations/)
        end
      end
    end
  end
end
