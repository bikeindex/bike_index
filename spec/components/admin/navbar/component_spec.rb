# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Navbar::Component, type: :component do
  let(:admin_bikes) { "/admin/bikes" }
  # Somewhere outside admin, so no nav link is the active one
  let(:url) { "/bikes/new" }
  let(:current_user) { FactoryBot.create(:superuser) }
  let(:component) { with_request_url(url) { render_inline(described_class.new(current_user:)) } }
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
    let(:active_shortcut) { "ul.navbar-nav a[aria-current]" }

    context "on a shortcut's own page" do
      let(:url) { admin_bikes }

      it "marks only that shortcut active" do
        expect(component.css(active_shortcut).map(&:text)).to eq(["Bikes"])
      end
    end

    # The shortcuts take their match from nav_select_links, so they stay active across a
    # section rather than only on its index
    context "on another page of the shortcut's controller" do
      let(:url) { "#{admin_bikes}/duplicates" }

      it "keeps that shortcut active" do
        expect(component.css(active_shortcut).map(&:text)).to eq(["Bikes"])
      end
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

      it "links to the unfiltered page" do
        expect(component).to have_css("#{view_all_link}[href='#{admin_bikes}']", text: /All\s+Bikes/)
      end
    end

    context "with a search param" do
      let(:url) { "#{admin_bikes}?search_email=party@example.com" }

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

      it "drops the prefix from the title" do
        expect(component).to have_css("#{view_all_link}[href='/admin/email_domains']", text: /All\s+Email Domains/)
      end
    end
  end
end
