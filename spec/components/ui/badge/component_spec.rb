# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Badge::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text:, color:}.compact }
  let(:text) { "Test Badge" }
  let(:color) { nil }

  it "renders with default gray color" do
    expect(component).to have_css("span")
    expect(component).to have_text("Test Badge")
    expect(component.to_html).to include("tw:bg-gray-500")
  end

  it "includes base classes" do
    html = component.to_html
    expect(html).to include("tw:inline-block")
    expect(html).to include("tw:text-white")
    expect(html).to include("tw:rounded-lg")
  end

  describe "colors" do
    {
      emerald: "tw:bg-emerald-500",
      blue: "tw:bg-blue-600",
      purple: "tw:bg-purple-800",
      amber: "tw:bg-amber-400",
      cyan: "tw:bg-cyan-600",
      red: "tw:bg-red-500",
      red_light: "tw:bg-red-400",
      gray: "tw:bg-gray-500"
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
      expect(component.to_html).to include("tw:bg-gray-500")
    end
  end
end
