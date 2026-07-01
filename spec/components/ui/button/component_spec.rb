# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Button::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text:, color:, size:}.compact }
  let(:text) { "Click me" }
  let(:color) { nil }
  let(:size) { nil }

  it "renders a button with default options" do
    expect(component).to have_css("button[type='button']")
    expect(component).to have_text("Click me")
    html = component.to_html
    expect(html).to include("tw:bg-gray-50")
    expect(html).to include("tw:border-gray-300")
  end

  context "with primary color" do
    let(:color) { :primary }

    it "renders primary styles" do
      expect(component.to_html).to include("tw:bg-blue-600")
    end
  end

  context "with error color" do
    let(:color) { :error }

    it "renders error styles" do
      expect(component.to_html).to include("tw:bg-red-600")
    end
  end

  context "with link color" do
    let(:color) { :link }

    it "renders link styles" do
      html = component.to_html
      expect(html).to include("tw:underline")
      expect(html).to include("tw:text-blue-600")
      expect(html).not_to include("tw:bg-blue-600")
    end

    context "with non-default size" do
      let(:size) { :lg }

      it "raises ArgumentError" do
        expect { instance }.to raise_error(ArgumentError, /size is not supported for link color/)
      end
    end
  end

  context "with invalid color" do
    let(:color) { :invalid }

    it "falls back to secondary" do
      expect(component.to_html).to include("tw:bg-gray-50")
    end
  end

  describe "sizes" do
    context "with sm" do
      let(:size) { :sm }

      it "renders small" do
        expect(component.to_html).to include("tw:text-xs")
      end
    end

    context "with lg" do
      let(:size) { :lg }

      it "renders large" do
        expect(component.to_html).to include("tw:text-base")
      end
    end
  end

  context "with active state" do
    let(:options) { {text: "Active", color: :primary, active: true} }

    it "includes active ring classes" do
      expect(component.to_html).to include("tw:ring-2")
    end
  end

  context "with submit kind" do
    let(:options) { {text: "Submit", kind: :submit} }

    it "renders submit button" do
      expect(component).to have_css("button[type='submit']")
    end
  end

  context "with block content" do
    it "renders block content" do
      component = render_inline(described_class.new) { "Block content" }
      expect(component).to have_text("Block content")
    end
  end

  context "with data attributes" do
    let(:options) { {text: "Click", data: {action: "click->ui--modal#open"}} }

    it "renders data attributes" do
      expect(component).to have_css("button[data-action='click->ui--modal#open']")
    end
  end

  it "always applies the prefixed active classes (inert until pressed/toggled)" do
    tokens = component.css("button").first["class"].split
    expect(tokens).to include("tw:aria-pressed:ring-2", "tw:active:ring-2")
    expect(tokens).not_to include("tw:ring-2", "tw:bg-gray-200")
  end

  context "with aria-controls" do
    let(:options) { {aria: {controls: "panel"}} }
    it "renders aria-controls" do
      expect(component.to_html).to include('aria-controls="panel"')
    end
  end

  context "active: true" do
    let(:options) { {active: true} }
    it "applies the bare active classes statically" do
      tokens = component.css("button").first["class"].split
      expect(tokens).to include("tw:ring-2", "tw:bg-gray-200")
    end
  end

  describe "ACTIVE_PREFIXED" do
    it "prefixes every ACTIVE_COLORS class with aria-pressed: and active: for each color" do
      expect(described_class::ACTIVE_PREFIXED.keys).to eq(described_class::ACTIVE_COLORS.keys)
      described_class::ACTIVE_COLORS.each do |color, classes|
        expected = classes.split.flat_map do |variant|
          base = variant.delete_prefix("tw:")
          ["tw:aria-pressed:#{base}", "tw:active:#{base}"]
        end
        expect(described_class::ACTIVE_PREFIXED[color].split).to eq(expected)
      end
    end
  end
end
