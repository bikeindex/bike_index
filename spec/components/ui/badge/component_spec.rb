# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Badge::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text:, color:, title:}.compact }
  let(:text) { "Test Badge" }
  let(:color) { nil }
  let(:title) { nil }

  it "renders with default gray color and no tooltip" do
    expect(component).to have_css("span")
    expect(component).to have_text("Test Badge")
    expect(component).not_to have_css("[role='tooltip']")

    html = component.to_html
    expect(html).to include("tw:bg-[#f0f0f2]")
    expect(html).to include("tw:inline-flex")
    expect(html).to include("tw:rounded-full")
    expect(html).to include("tw:cursor-default")
  end

  context "with title equal to text" do
    let(:title) { "Test Badge" }
    it "does not render a tooltip" do
      expect(component).not_to have_css("[role='tooltip']")
      expect(component.to_html).to include("tw:cursor-default")
    end
  end

  context "with custom title differing from text" do
    let(:title) { "Custom Title" }
    it "wraps in a UI::Tooltip with cursor-help" do
      expect(component.css("[role='tooltip']").text.strip).to eq "Custom Title"
      expect(component.to_html).to include("tw:cursor-help")
      expect(component).to have_text("Test Badge")
    end
  end

  describe "colors" do
    {
      success: "tw:bg-green-50",
      notice: "tw:bg-blue-50",
      purple: "tw:bg-purple-50",
      warning: "tw:bg-amber-50",
      cyan: "tw:bg-cyan-50",
      error: "tw:bg-red-50",
      gray: "tw:bg-[#f0f0f2]",
      rose: "tw:bg-rose-50",
      orange: "tw:bg-orange-50",
      empty: "tw:bg-white"
    }.each do |color_name, css_class|
      context "with #{color_name}" do
        let(:color) { color_name }
        it "renders with #{css_class}" do
          expect(component.to_html).to include(css_class)
        end
      end
    end
  end

  context "with invalid color" do
    let(:color) { :invalid_color }
    it "falls back to gray" do
      expect(component.to_html).to include("tw:bg-[#f0f0f2]")
    end
  end

  context "with empty color" do
    let(:color) { :empty }
    it "renders with gray border" do
      html = component.to_html
      expect(html).to include("tw:bg-white")
      expect(html).to include("tw:border-gray-300")
    end
  end

  describe "decorative leading elements" do
    context "with an icon" do
      let(:options) { {text:, icon: "link"} }

      it "hides the icon from screen readers" do
        expect(component.css("svg[aria-hidden='true']")).to be_present
        expect(component).to have_text("Test Badge")
      end
    end

    context "with an indicator" do
      let(:options) { {text:, indicator: true} }

      it "hides the dot from screen readers" do
        expect(component.css("span[aria-hidden='true']")).to be_present
      end
    end
  end

  context "with content block" do
    let(:component) { render_inline(described_class.new(text: "Fallback")) { "Block content" } }

    it "renders block content instead of text" do
      expect(component).to have_text("Block content")
      expect(component).not_to have_text("Fallback")
    end
  end

  context "without content block" do
    it "renders text" do
      expect(component).to have_text("Test Badge")
    end
  end
end
