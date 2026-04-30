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
end
