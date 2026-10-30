# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::SectionHeading::Component, type: :component do
  let(:options) { {heading: "Questions"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders only the heading" do
    expect(component.css("h2").text).to match "Questions"
    expect(component.css("p").count).to eq 0
  end

  context "with a label and intro" do
    let(:options) { {heading: "Registration", eyebrow: "Program", eyebrow_color: :purple, intro: "One registry"} }

    it "renders them around the heading" do
      expect(component.css("p.tw\\:text-purple-500").text).to match "Program"
      expect(component.css("h2 + p").text).to match "One registry"
    end
  end
end
