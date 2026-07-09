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
      expect(swatch["title"]).to eq "Blue"
      expect(component.to_html).to include("tw:inline-block")
      expect(component.to_html).to include("tw:rounded-xs")
    end
  end

  context "with the cover-up color" do
    let(:name) { Color::COVER_UP_NAME }

    it "renders the multicolor blend instead of a solid fill" do
      swatch = component.css("span").first
      expect(swatch["style"]).to eq "background: #{Color::COVER_UP_SWATCH}"
      expect(swatch["title"]).to eq Color::COVER_UP_NAME
    end
  end
end
