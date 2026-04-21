# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::MultiResultChip::Component, type: :component do
  let(:component) { render_inline(described_class.new(serial:, chip_id:, result_count:, error:)) }
  let(:serial) { "SERIAL111" }
  let(:chip_id) { "chip_0" }
  let(:result_count) { 1 }
  let(:error) { false }

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

  context "with error" do
    let(:error) { true }

    it "renders error badge" do
      expect(component).to have_css("span#chip_0")
      expect(component).not_to have_css("a")
      expect(component).to have_css("span.serial-span", text: "SERIAL111")
      expect(component).to have_css("small", text: "error")
    end

    it "uses error badge classes" do
      expect(component.to_html).to include("tw:bg-red-300")
    end
  end
end
