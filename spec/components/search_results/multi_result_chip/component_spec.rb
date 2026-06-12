# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::MultiResultChip::Component, type: :component do
  let(:component) { render_inline(described_class.new(chip_id:, result_count:, serial:, error:, error_message:)) }
  let(:serial) { "SERIAL111" }
  let(:chip_id) { "chip_0" }
  let(:result_count) { 1 }
  let(:error) { false }
  let(:error_message) { nil }

  context "with results" do
    it "renders badge with link inside" do
      expect(component).to have_css("span#chip_0")
      expect(component).to have_css("span#chip_0 a[href='#result_0']", text: "SERIAL111")
    end

    it "uses success badge classes" do
      expect(component.to_html).to include("tw:bg-emerald-500")
    end

    it "underlines the link" do
      expect(component.to_html).to include("tw:underline!")
    end
  end

  context "with no results" do
    let(:result_count) { 0 }

    it "renders as a span" do
      expect(component).to have_css("span#chip_0")
      expect(component).not_to have_css("a")
      expect(component).to have_css("span.serial-span", text: "SERIAL111")
    end

    it "uses gray badge classes" do
      expect(component.to_html).to include("tw:bg-gray-300")
    end

    it "does not underline the serial span" do
      expect(component).not_to have_css("span.tw\\:underline")
    end
  end

  context "with sticker instead of serial" do
    let(:component) { render_inline(described_class.new(chip_id:, result_count:, sticker: "STKR100")) }

    it "uses the sticker as the chip label" do
      expect(component).to have_css("span#chip_0 a", text: "STKR100")
    end
  end

  context "with neither serial nor sticker" do
    it "raises ArgumentError" do
      expect { described_class.new(chip_id:, result_count:) }.to raise_error(ArgumentError, /serial: or sticker:/)
    end
  end

  context "with both serial and sticker" do
    it "raises ArgumentError" do
      expect { described_class.new(chip_id:, result_count:, serial: "S1", sticker: "K1") }.to raise_error(ArgumentError, /serial: or sticker:/)
    end
  end

  context "with error" do
    let(:error) { true }

    it "renders error badge without a tooltip" do
      expect(component).to have_css("span#chip_0")
      expect(component).not_to have_css("a")
      expect(component).not_to have_css("[role=tooltip]", visible: :all)
      expect(component).to have_css("span.serial-span", text: "SERIAL111")
      expect(component).to have_css("small", text: "error")
    end

    it "uses error badge classes" do
      expect(component.to_html).to include("tw:bg-red-300")
    end

    context "with error_message" do
      let(:error_message) { "Server error 500" }

      it "wraps the error label in a tooltip showing the message and uses the help cursor" do
        expect(component).to have_css("button[data-controller~='ui--tooltip'] small", text: "error")
        expect(component).to have_css("[role=tooltip]", text: "Server error 500", visible: :all)
        expect(component.to_html).to include("tw:cursor-help")
      end
    end
  end
end
