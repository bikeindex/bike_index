# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Headers::Nav::Component, type: :component do
  let(:component) { render_inline(described_class.new(title: "Manage Bikes")) }

  it "renders the title through UI::Header, with the rule under it" do
    expect(component.css("h1").text.squish).to eq "Manage Bikes"
    expect(component).to have_css("div.tw\\:border-b")
    expect(component).not_to have_css("ul")
  end

  # A caller whose items all render conditionally would otherwise get a bordered empty list
  context "with a block rendering nothing" do
    let(:component) { render_inline(described_class.new(title: "Manage Bikes")) { "\n  \n".html_safe } }

    it "renders no list" do
      expect(component).not_to have_css("ul")
    end
  end

  context "with a subtitle and items" do
    let(:component) do
      render_inline(described_class.new(title: "Manage Bikes", subtitle: "Editing", border: false)) do
        "<li><a href='/one'>One</a></li>".html_safe
      end
    end

    it "lists the items and drops the rule" do
      expect(component.css("ul li a").map { |link| link.text }).to eq %w[One]
      expect(component).to have_content("Editing")
      expect(component).not_to have_css("div.tw\\:border-b")
    end
  end
end
