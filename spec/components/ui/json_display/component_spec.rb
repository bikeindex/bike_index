# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::JsonDisplay::Component, type: :component do
  let(:component) { render_inline(described_class.new(data:, **options)) }
  let(:data) { {owner_email: "mothman@bikeindex.org", stolen: false, bike_sticker: nil} }
  let(:options) { {} }

  it "renders every value, full width and full size" do
    expect(component).to have_css("div.highlightjs-json[data-controller='ui--json-display'] pre code.language-json")
    expect(component.text).to include "bike_sticker"
    expect(component).to_not have_css("div.highlightjs-json[style]")
    expect(component).to have_css("div.highlightjs-json pre.tw\\:max-h-72")
  end

  context "with no_max_height" do
    let(:options) { {no_max_height: true} }

    it "adds the class that drops the height cap" do
      expect(component).to_not have_css("pre.tw\\:max-h-72")
    end
  end

  context "with small and max_width" do
    let(:options) { {small: true, max_width: 450} }

    it "renders the pixel width and the smaller text" do
      expect(component).to have_css("div.highlightjs-json.tw\\:text-xs[style='max-width: 450px;']")
    end
  end

  context "with max_width: :table_cell" do
    let(:options) { {max_width: :table_cell} }

    it "resolves the name to its pixel width and adds the cell-filling class" do
      expect(component).to have_css("div.highlightjs-json.highlightjs-json-cell[style='max-width: 500px;']")
    end
  end

  context "with a max_width that is neither" do
    let(:options) { {max_width: :sidebar} }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /must be an integer .* or :table_cell/)
    end
  end

  context "with a pixel max_width" do
    let(:options) { {max_width: 300} }

    it "does not add the cell-filling class" do
      expect(component).to have_css("div.highlightjs-json[style='max-width: 300px;']")
      expect(component).to_not have_css("div.highlightjs-json-cell")
    end
  end

  context "with skip_blank" do
    let(:options) { {skip_blank: true} }

    it "drops the nil value but keeps the false one" do
      expect(component.text).to_not include "bike_sticker"
      expect(component.text).to include "stolen"
    end
  end

  context "with blank data" do
    let(:data) { {} }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
