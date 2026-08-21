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

  context "shadow and additional_classes" do
    it "appends both" do
      render_inline(described_class.new(shadow: true, additional_classes: "tw:mt-8"))

      expect(page).to have_css("div[class~='tw:shadow-sm'][class~='tw:mt-8']")
    end
  end
end
