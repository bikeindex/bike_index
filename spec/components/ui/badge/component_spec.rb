# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Badge::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text:, color:, title:}.compact }
  let(:text) { "Test Badge" }
  let(:color) { nil }
  let(:title) { nil }

  it "renders with default gray color" do
    expect(component).to have_css("span")
    expect(component).to have_text("Test Badge")
    expect(component).to have_css("span[title='Test Badge']")

    html = component.to_html
    expect(html).to include("tw:bg-gray-300")
    expect(html).to include("tw:inline-flex")
    expect(html).to include("tw:rounded-full")
  end

  context "with custom title" do
    let(:title) { "Custom Title" }
    it "uses custom title" do
      expect(component).to have_css("span[title='Custom Title']")
      expect(component).to have_text("Test Badge")
    end
  end

  describe "colors" do
    {
      success: "tw:bg-emerald-500",
      notice: "tw:bg-blue-300",
      purple: "tw:bg-purple-300",
      warning: "tw:bg-amber-300",
      cyan: "tw:bg-cyan-400",
      error: "tw:bg-red-300",
      gray: "tw:bg-gray-300"
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
      expect(component.to_html).to include("tw:bg-gray-300")
    end
  end
end
