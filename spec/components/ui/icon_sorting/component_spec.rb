# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::IconSorting::Component, type: :component do
  context "with desc" do
    let(:component) { render_inline(described_class.new(direction: "desc")) }

    it "renders a down chevron" do
      expect(component.css("svg").first[:class]).to include("tw:rotate-90")
    end
  end

  context "with asc" do
    let(:component) { render_inline(described_class.new(direction: "asc")) }

    it "renders an up chevron" do
      expect(component.css("svg").first[:class]).to include("tw:rotate-270")
    end
  end

  context "with an unknown direction" do
    let(:component) { render_inline(described_class.new(direction: "sideways")) }

    it "falls back to a down chevron" do
      expect(component.css("svg").first[:class]).to include("tw:rotate-90")
    end
  end

  context "with html_class" do
    let(:component) { render_inline(described_class.new(direction: "asc", html_class: "tw:ml-1")) }

    it "passes classes through to the chevron" do
      expect(component.css("svg").first[:class]).to include("tw:ml-1")
    end
  end
end
