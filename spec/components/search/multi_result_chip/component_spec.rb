# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::MultiResultChip::Component, type: :component do
  let(:component) { render_inline(described_class.new(serial:, serial_chip_id:, result_count:)) }
  let(:serial) { "SERIAL111" }
  let(:serial_chip_id) { "chip_0" }
  let(:result_count) { 1 }

  context "with results" do
    it "renders as a link to the result anchor" do
      expect(component).to have_css("a#chip_0[href='#result_0']")
      expect(component).to have_css("span.serial-span", text: "SERIAL111")
    end

    it "uses success badge classes" do
      expect(component.to_html).to include("tw:bg-emerald-500")
    end

    it "underlines the serial span" do
      expect(component).to have_css("span.tw\\:underline")
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
end
