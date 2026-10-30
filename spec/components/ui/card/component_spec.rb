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

  context "full_bleed" do
    # What it drops, and the width it drops them at, are .twfullbleed's under a container
    # query on the row - all the card owes is the class
    it "marks the card for the row to bleed, without unsetting anything itself" do
      render_inline(described_class.new(full_bleed: true)) { "in the card" }

      expect(page).to have_css("div[class~='tw:twfullbleed'][class~='tw:border'][class~='tw:p-4']")
    end

    it "leaves the class off otherwise" do
      render_inline(described_class.new) { "in the card" }

      expect(page).to have_no_css("div[class~='tw:twfullbleed']")
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

  context "shadow" do
    it "adds a small shadow to the gray border, alongside additional_classes" do
      render_inline(described_class.new(shadow: :small, additional_classes: "tw:mt-8"))

      expect(page).to have_css("div[class~='tw:shadow-sm'][class~='tw:border-gray-200'][class~='tw:mt-8']")
    end

    it "adds a large shadow to the gray border" do
      render_inline(described_class.new(shadow: :large)) { "in the card" }

      expect(page).to have_css("div[class~='tw:shadow-[0_10px_30px_rgba(44,62,80,.16)]'][class~='tw:border-gray-200']")
    end

    it "swaps the gray border for the sticker's with a black shadow" do
      render_inline(described_class.new(shadow: :black)) { "in the card" }

      expect(page).to have_css("div[class~='tw:border-3'][class~='tw:shadow-[4px_4px_0_#111]'][class~='tw:p-4']")
      expect(page).to have_no_css("div[class~='tw:border-gray-200']")
    end

    it "has none by default" do
      render_inline(described_class.new) { "in the card" }

      expect(page).to have_no_css("div[class*='shadow']")
    end

    it "rejects anything else" do
      expect { described_class.new(shadow: true) }.to raise_error(ArgumentError, /unknown shadow true/)
    end
  end
end
