# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::RecordTabs::Component, type: :component do
  let(:tabs) do
    [{label: "Show", href: "/admin/things/1", active: true},
      {label: "Edit", href: "/admin/things/1/edit", active: false}]
  end
  let(:component) { render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections")) }

  it "renders the title and the tabs, marking the active one" do
    expect(component.at_css("h1").text.squish).to eq "A Thing"
    expect(component.css(".nav-tabs .nav-link").map { |tab| tab.text.squish }).to eq %w[Show Edit]
    expect(component.css(".nav-tabs .nav-link.active").map { |tab| tab.text.squish }).to eq ["Show"]
    expect(component.css(".nav-tabs .nav-link[aria-current]").map { |tab| tab.text.squish }).to eq ["Show"]
    expect(component.at_css("nav")["aria-label"]).to eq "Thing sections"
  end

  it "renders no links and no alert when it's given neither" do
    expect(component.css(".admin-subnav ul .nav-item")).to be_empty
    expect(component).not_to have_css("[role='alert']")
  end

  context "with a subtitle, links and an alert" do
    let(:component) do
      links = ["<a href='/one'>One</a>".html_safe, "<a href='/two'>Two</a>".html_safe]
      render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections",
        subtitle: "Editing", links:)) do |record_tabs|
        record_tabs.with_alert { "<p>Thing deleted</p>".html_safe }
      end
    end

    it "renders each of them" do
      expect(component.at_css("h1").text.squish).to eq "A Thing Editing"
      expect(component.css(".admin-subnav ul .nav-item a").map { |link| link.text }).to eq %w[One Two]
      expect(component).to have_content("Thing deleted")
    end
  end
end
