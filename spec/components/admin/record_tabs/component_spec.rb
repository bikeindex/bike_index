# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::RecordTabs::Component, type: :component do
  let(:tabs) do
    [{label: "Show", href: "/admin/things/1", active: true},
      {label: "Edit", href: "/admin/things/1/edit", active: false}]
  end
  let(:component) { render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections")) }

  # aria-current took the tab's own boolean once, so every inactive tab rendered
  # aria-current="false" - which counts as current
  it "marks only the active tab, in the class and in aria" do
    expect(component.css(".nav-tabs .nav-link.active").map { |tab| tab.text.squish }).to eq ["Show"]
    expect(component.css(".nav-tabs .nav-link[aria-current]").map { |tab| tab.text.squish }).to eq ["Show"]
  end

  context "with a subtitle, links and an alert" do
    let(:component) do
      links = ["<a href='/one'>One</a>".html_safe, "<a href='/two'>Two</a>".html_safe]
      render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections",
        subtitle: "Editing", links:)) do |record_tabs|
        record_tabs.with_alert { "<p>Thing deleted</p>".html_safe }
      end
    end

    it "renders the links and the alert slot" do
      expect(component.css(".admin-subnav ul .nav-item a").map { |link| link.text }).to eq %w[One Two]
      expect(component).to have_content("Thing deleted")
    end
  end
end
