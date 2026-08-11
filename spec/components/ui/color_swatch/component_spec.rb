# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ColorSwatch::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {display:, name:}.compact }
  let(:display) { nil }
  let(:name) { nil }

  context "with a display color" do
    let(:display) { "#386ed2" }
    let(:name) { "Blue" }

    it "renders a solid swatch using the display color" do
      swatch = component.css("span").first
      expect(swatch["style"]).to eq "background: #386ed2"
      expect(component.to_html).to include("tw:inline-block")
      expect(component.to_html).to include("tw:rounded-xs")
    end

    it "is hidden from screen readers, which read the name beside it" do
      swatch = component.css("span").first
      expect(swatch["aria-hidden"]).to eq "true"
      expect(swatch["title"]).to be_nil
    end

    it "defaults to the md size, middle alignment" do
      tokens = component.css("span").first["class"].split
      expect(tokens).to include("tw:h-6", "tw:w-6", "tw:align-middle")
    end
  end

  context "with size: :sm" do
    let(:options) { {display: "#386ed2", size: :sm} }

    it "renders the small size" do
      tokens = component.css("span").first["class"].split
      expect(tokens).to include("tw:h-3", "tw:w-3")
      expect(tokens).to_not include("tw:h-6")
    end
  end

  context "with align: :baseline" do
    let(:options) { {display: "#386ed2", align: :baseline} }

    it "renders baseline alignment" do
      tokens = component.css("span").first["class"].split
      expect(tokens).to include("tw:align-baseline")
      expect(tokens).to_not include("tw:align-middle")
    end
  end

  context "with invalid size and align" do
    let(:options) { {display: "#386ed2", size: :huge, align: :top} }

    it "falls back to md and middle" do
      tokens = component.css("span").first["class"].split
      expect(tokens).to include("tw:h-6", "tw:w-6", "tw:align-middle")
    end
  end

  context "with the cover-up color" do
    let(:name) { Color::COVER_UP_NAME }

    it "renders the multicolor blend instead of a solid fill" do
      swatch = component.css("span").first
      expect(swatch["style"]).to eq "background: #{Color::COVER_UP_SWATCH}"
    end
  end
end
