# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Headers::Tabs::Component, type: :component do
  let(:tabs) do
    [{label: "Show", href: "/admin/things/1", active: true},
      {label: "Edit", href: "/admin/things/1/edit", active: false}]
  end
  let(:component) { render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections")) }

  # Which tab is active is UI::Tabs' to get right; this is that they reach it at all
  it "hands its tabs to UI::Tabs" do
    expect(component.css("nav a").map { |tab| tab.text.squish }).to eq %w[Show Edit]
  end

  context "with a summary" do
    let(:component) do
      render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections")) do |header|
        header.with_summary { "<h4>About the thing</h4>".html_safe }
      end
    end

    it "renders it flush under the tabs" do
      expect(component.at_css("nav[aria-label='Thing sections'] + div h4").text).to eq "About the thing"
      expect(component.at_css("nav[aria-label='Thing sections']")["class"]).to include("tw:mb-0")
    end
  end

  context "with a subtitle, links and an alert" do
    let(:component) do
      render_inline(described_class.new(title: "A Thing", tabs:, nav_label: "Thing sections",
        subtitle: "Editing")) do |header|
        header.with_nav_item { "<a href='/one'>One</a>".html_safe }
        header.with_nav_item { "<a href='/two'>Two</a>".html_safe }
        header.with_alert { "<p>Thing deleted</p>".html_safe }
      end
    end

    it "renders the links and the alert slot" do
      expect(component.css("ul li a").map { |link| link.text }).to eq %w[One Two]
      expect(component).to have_content("Editing")
      expect(component).to have_content("Thing deleted")
    end
  end
end
