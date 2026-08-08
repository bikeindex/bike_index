# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Combobox::Component, type: :component do
  let(:admin_bikes) { "/admin/bikes" }
  # Somewhere outside admin, so no nav link is the active one
  let(:url) { "/bikes/new" }
  let(:options) { {} }
  let(:component) { with_request_url(url) { render_inline(described_class.new(**options)) } }

  it "renders an option per admin page, minus the dev pages, and prompts because none match" do
    expect(component).to have_css("[data-controller='admin--combobox'][data-action='hw-combobox:selection->admin--combobox#navigate']")
    expect(component).to have_css("[role='option'][data-value='#{admin_bikes}']", text: "Bikes", visible: :all)
    expect(component).to have_css("[role='option'][data-value='/admin/organizations']", text: "Organizations", visible: :all)
    expect(component).to_not have_css("[role='option'][data-value='/admin/feature_flags']", visible: :all)
    expect(component).to have_css("input[role='combobox'][placeholder='Admin navigation']")
    expect(component).to_not have_css("a.nav-link")
  end

  context "with developer" do
    let(:options) { {developer: true} }

    it "adds the dev pages, sorted in among the rest" do
      expect(component).to have_css("[role='option'][data-value='/admin/feature_flags']", text: "Dev: Feature Flags", visible: :all)
      expect(component.css("[role='option']").map(&:text)).to eq component.css("[role='option']").map(&:text).sort
    end
  end

  describe "the view all link" do
    context "period all" do
      let(:url) { "#{admin_bikes}?period=all&timezone=Party" }

      it "names the active page, without a view all link" do
        expect(component).to have_css("input[role='combobox'][placeholder='Viewing Bikes']")
        expect(component).to_not have_css("a.nav-link")
      end
    end

    context "with sort" do
      let(:url) { "#{admin_bikes}?direction=desc&render_chart=true&sort=manufacturer_id" }

      it "renders no view all link" do
        expect(component).to_not have_css("a.nav-link")
      end
    end

    context "with period != all" do
      let(:url) { "#{admin_bikes}?period=week&timezone=Party" }

      it "links to the unfiltered page" do
        expect(component).to have_css("a.nav-link[href='#{admin_bikes}']", text: /All\s+Bikes/)
      end
    end

    context "with a search param" do
      let(:url) { "#{admin_bikes}?search_email=party@example.com" }

      it "links to the unfiltered page" do
        expect(component).to have_css("a.nav-link[href='#{admin_bikes}']", text: /All\s+Bikes/)
      end
    end

    context "on another page of the same controller" do
      let(:url) { "#{admin_bikes}/duplicates" }

      it "links to the unfiltered page" do
        expect(component).to have_css("a.nav-link[href='#{admin_bikes}']", text: /All\s+Bikes/)
      end
    end

    context "on a Config: page" do
      let(:url) { "/admin/email_domains?search_status=banned" }

      it "drops the prefix from the title" do
        expect(component).to have_css("a.nav-link[href='/admin/email_domains']", text: /All\s+Email Domains/)
      end
    end
  end
end
