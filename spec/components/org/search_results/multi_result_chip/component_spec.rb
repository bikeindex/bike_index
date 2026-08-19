# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::SearchResults::MultiResultChip::Component, type: :component do
  let(:component) { render_inline(described_class.new(chip_id:, result_count:, label:, search_kind:, error:, error_message:)) }
  let(:label) { "SERIAL111" }
  let(:search_kind) { "serials" }
  let(:chip_id) { "chip_0" }
  let(:result_count) { 1 }
  let(:error) { false }
  let(:error_message) { nil }

  context "with results" do
    it "renders badge with link inside" do
      expect(component).to have_css("span#chip_0")
      expect(component).to have_css("span#chip_0 a[href='#result_0'] span.serial-span", text: "SERIAL111")
    end

    it "uses success badge classes" do
      expect(component.to_html).to include("tw:bg-green-50")
    end

    it "underlines the link" do
      expect(component.to_html).to include("tw:underline!")
    end

    it "pads the link rather than the serial, which is inline" do
      expect(component).to have_css("a.tw\\:py-1.tw\\:px-2 > span.serial-span")
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
      expect(component.to_html).to include("tw:bg-[#f0f0f2]")
    end

    it "does not underline the serial span" do
      expect(component).not_to have_css("span.tw\\:underline")
    end
  end

  context "searching stickers" do
    let(:label) { "STKR 100" }
    let(:search_kind) { "stickers" }

    it "renders the code through the sticker atom" do
      expect(component).to have_css("span#chip_0 a[href='#result_0'] code", text: label)
      expect(component).to have_no_css("span.serial-span")
    end

    context "with no results" do
      let(:result_count) { 0 }

      it "renders the code without a link" do
        expect(component).to have_css("span#chip_0 code", text: label)
        expect(component).to have_no_css("a")
      end
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
      expect(component.to_html).to include("tw:bg-red-50")
    end

    context "with error_message" do
      let(:error_message) { "Server error 500" }

      it "wraps the error label in a tooltip showing the message and uses the help cursor" do
        expect(component).to have_css("[data-controller~='ui--tooltip'] button small", text: "error")
        expect(component).to have_css("[role=tooltip]", text: "Server error 500", visible: :all)
        expect(component.to_html).to include("tw:cursor-help")
      end
    end
  end
end
