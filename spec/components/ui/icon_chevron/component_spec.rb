# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::IconChevron::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {} }

  it "renders the chevron svg pointing right by default" do
    svg = component.css("svg").first
    expect(svg[:class]).to include("tw:inline-block")
    expect(svg[:class]).to include("tw:h-3 tw:w-3")
    expect(svg[:class]).not_to include("rotate")
  end

  context "with direction: :down" do
    let(:options) { {direction: :down} }

    it "rotates the chevron" do
      expect(component.css("svg").first[:class]).to include("tw:rotate-90")
    end
  end

  context "with direction: :up" do
    let(:options) { {direction: :up} }

    it "rotates the chevron" do
      expect(component.css("svg").first[:class]).to include("tw:rotate-270")
    end
  end

  context "with an unknown direction" do
    let(:options) { {direction: :sideways} }

    it "falls back to right" do
      expect(component.css("svg").first[:class]).not_to include("rotate")
    end
  end

  context "with size: :md" do
    let(:options) { {size: :md} }

    it "renders a larger chevron" do
      expect(component.css("svg").first[:class]).to include("tw:h-4 tw:w-4")
    end
  end

  context "with extra classes" do
    let(:options) { {html_class: "tw:ml-1"} }

    it "appends the classes" do
      expect(component.css("svg").first[:class]).to include("tw:ml-1")
    end
  end
end
