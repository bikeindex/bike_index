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
    expect(html).to include("tw:bg-white")
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
      expect(html).to include("twlink")
      expect(html).not_to include("tw:text-blue-600")
      expect(html).not_to include("tw:bg-blue-600")
    end

    context "with non-default size" do
      let(:size) { :lg }

      it "raises ArgumentError" do
        expect { instance }.to raise_error(ArgumentError, /size is not supported for link color/)
      end
    end
  end

  context "with purple_outline color" do
    let(:color) { :purple_outline }

    it "renders purple_outline styles" do
      expect(component.to_html).to include("tw:hover:border-purple-500")
    end
  end

  context "with invalid color" do
    let(:color) { :invalid }

    it "falls back to secondary" do
      expect(component.to_html).to include("tw:bg-white")
    end
  end

  context "with disabled" do
    let(:options) { {text: "Click", disabled: true} }

    it "disables the button and applies disabled styling" do
      expect(component).to have_css("button[disabled]")
      tokens = component.css("button").first["class"].split
      expect(tokens).to include(*described_class::DISABLED_CLASSES.split)
    end
  end

  it "is not disabled by default" do
    expect(component).to have_no_css("button[disabled]")
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
      expect(component).to have_css("button[data-active='true']")
      expect(component.to_html).to include("tw:is-active:ring-2", "tw:is-active:ring-blue-500/40")
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

  it "always applies the active classes (inert until data-active/pressed)" do
    tokens = component.css("button").first["class"].split
    expect(tokens).to include("tw:is-active:ring-2", "tw:is-active:bg-gray-200")
    expect(component).to have_no_css("button[data-active]")
  end

  it "keeps focus visible on an active button, whose ring would otherwise mask it" do
    tokens = component.css("button").first["class"].split
    expect(tokens).to include("tw:focus:ring-3", "tw:is-active:focus:ring-3")
  end

  context "with aria-controls" do
    let(:options) { {aria: {controls: "panel"}} }
    it "renders aria-controls" do
      expect(component.to_html).to include('aria-controls="panel"')
    end
  end

  context "active: true" do
    let(:options) { {active: true} }
    it "flags the button data-active, leaving the classes unchanged" do
      expect(component).to have_css("button[data-active='true']")
      expect(component.css("button").first["class"].split).to eq(instance.class.build_classes(color: :secondary, size: :md).split)
    end
  end

  describe "ACTIVE_COLORS" do
    # Every active class is variant-prefixed, so it can never compete with the resting
    # color it overrides — that's what lets both sets be emitted without `!` important.
    it "covers every color, prefixed with tw:is-active:" do
      expect(described_class::ACTIVE_COLORS.keys).to eq(described_class::COLORS.keys)
      described_class::ACTIVE_COLORS.each_value do |classes|
        expect(classes.split.grep_v(/\Atw:is-active:/)).to eq([])
      end
    end
  end

  # ACTIVE_COLORS is inert without this variant, which is what the deleted
  # aria-pressed:/active: mirror used to spell out class by class.
  describe "the is-active variant" do
    let(:stylesheet) { Rails.root.join("app/assets/tailwind/application.css").read }

    it "triggers on the persistent, toggled and pressed states" do
      selectors = stylesheet[/^@custom-variant is-active \((.*)\);/, 1]
      expect(selectors).to include('[data-active="true"]', '[aria-pressed="true"]', "[aria-current]", ":active")
    end

    it "is declared last, so it outranks the colors it overrides" do
      expect(stylesheet.scan(/^@custom-variant (\S+)/).flatten.last).to eq("is-active")
    end
  end
end
