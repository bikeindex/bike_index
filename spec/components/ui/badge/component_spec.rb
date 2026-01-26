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

  context "with emerald color" do
    let(:color) { :emerald }
    it "renders with emerald background" do
      expect(component.to_html).to include("tw:bg-emerald-500")
    end
  end

  context "with red color" do
    let(:color) { :red }
    it "renders with red background" do
      expect(component.to_html).to include("tw:bg-red-500")
    end
  end

  context "with invalid color" do
    let(:color) { :invalid_color }
    it "falls back to gray" do
      expect(component.to_html).to include("tw:bg-gray-500")
    end
  end
end
