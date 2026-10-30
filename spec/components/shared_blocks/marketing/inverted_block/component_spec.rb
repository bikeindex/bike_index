# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::InvertedBlock::Component, type: :component do
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(**options)) { "<p>Partner with us</p>".html_safe } }
  let(:grid_classes) { component.css("section.inverted > div").first["class"].split }

  it "renders the content inside an inverted section with the default padding" do
    expect(component.css("section.inverted p").text).to eq "Partner with us"
    expect(grid_classes).to include("tw:py-20")
  end

  context "with an html_class" do
    let(:options) { {html_class: "tw:gap-6"} }

    it "keeps the default padding" do
      expect(grid_classes).to include("tw:py-20", "tw:gap-6")
    end
  end

  context "with its own padding" do
    let(:options) { {html_class: "tw:py-16"} }

    it "drops the default padding" do
      expect(grid_classes).to include("tw:py-16")
      expect(grid_classes).not_to include("tw:py-20")
    end
  end
end
