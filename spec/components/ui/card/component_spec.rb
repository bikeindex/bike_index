# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Card::Component, type: :component do
  let(:options) { {} }

  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(component).to be_present
  end

  it "pads its content" do
    render_inline(described_class.new) { "in the card" }

    expect(page).to have_css("div[class~='tw:p-4'][class~='tw:rounded-sm'][class~='tw:border']")
    expect(page).to have_content("in the card")
  end

  context "mobile_flush" do
    it "drops the top and side borders and the padding below md, keeping the bottom" do
      render_inline(described_class.new(mobile_flush: true)) { "in the card" }

      expect(page).to have_css("div[class~='tw:max-md:border-x-0'][class~='tw:max-md:border-t-0'][class~='tw:max-md:px-0']")
      # one rule below each card is what separates a stack of them
      expect(page).to have_no_css("div[class~='tw:max-md:border-b-0']")
      expect(page).to have_css("div[class~='tw:border'][class~='tw:p-4']")
    end
  end

  context "divided" do
    it "divides its rows instead of padding" do
      render_inline(described_class.new(divided: true)) { "<p>row one</p><p>row two</p>".html_safe }

      expect(page).to have_css("div[class~='tw:divide-y'][class~='tw:rounded-xl'][class~='tw:border']")
      expect(page).to have_no_css("div[class~='tw:p-4']")
      expect(page).to have_content("row one")
      expect(page).to have_content("row two")
    end
  end

  context "shadow and additional_classes" do
    it "appends both" do
      render_inline(described_class.new(shadow: true, additional_classes: "tw:mt-8"))

      expect(page).to have_css("div[class~='tw:shadow-sm'][class~='tw:mt-8']")
    end
  end
end
