# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::LoadingSpinner::Component, type: :component do
  context "with text" do
    let(:component) { render_inline(described_class.new(text: "Loading results...")) }

    it "renders wrapper div with text and spinner" do
      expect(component.css("div.tw\\:animate-pulse")).to be_present
      expect(component.css("p").text).to eq("Loading results...")
      expect(component.css("svg.tw\\:animate-spin")).to be_present
    end

    it "is not inline" do
      expect(described_class.new(text: "Loading").inline?).to be false
    end

    it "renders svg with mx-auto" do
      expect(component.css("svg.tw\\:mx-auto")).to be_present
    end
  end

  context "without text" do
    let(:component) { render_inline(described_class.new) }

    it "renders inline svg only" do
      expect(component.css("div")).to be_empty
      expect(component.css("p")).to be_empty
      expect(component.css("svg.tw\\:animate-spin")).to be_present
    end

    it "is inline" do
      expect(described_class.new.inline?).to be true
    end

    it "renders svg with inline class" do
      expect(component.css("svg.tw\\:inline")).to be_present
    end
  end

  context "with size: :sm" do
    let(:component) { render_inline(described_class.new(size: :sm)) }

    it "renders small svg" do
      svg = component.css("svg").first
      expect(svg[:class]).to include("tw:h-3 tw:w-3")
    end
  end

  context "with size: :md" do
    let(:component) { render_inline(described_class.new(text: "Loading", size: :md)) }

    it "renders medium svg" do
      svg = component.css("svg").first
      expect(svg[:class]).to include("tw:h-15 tw:w-15")
    end
  end
end
