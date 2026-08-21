# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Headers::Tabs::Component, type: :component do
  let(:tabs) do
    [{label: "Show", href: "/admin/things/1", active: true},
      {label: "Edit", href: "/admin/things/1/edit", active: false}]
  end
  let(:component) { render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections")) }

  # Which tab is active is UI::Tabs' to get right; this is that they reach it at all
  it "hands its tabs to UI::Tabs" do
    expect(component.css("nav a").map { |tab| tab.text.squish }).to eq %w[Show Edit]
  end

  context "with a subtitle, links and an alert" do
    let(:component) do
      links = ["<a href='/one'>One</a>".html_safe, "<a href='/two'>Two</a>".html_safe]
      render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections",
        subtitle: "Editing", links:)) do |header|
        header.with_alert { "<p>Thing deleted</p>".html_safe }
      end
    end

    it "renders the links and the alert slot" do
      expect(component.css(".admin-subnav ul .nav-item a").map { |link| link.text }).to eq %w[One Two]
      expect(component).to have_content("Thing deleted")
    end
  end
end
