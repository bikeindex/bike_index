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
    expect(html).to include("tw:border-gray-200")
  end

  context "with primary color" do
    let(:color) { :primary }

    it "renders primary styles" do
      expect(component.to_html).to include("tw:bg-blue-600")
    end
  end

  context "with error color" do
    let(:color) { :error }

    it "renders the danger outline styles" do
      expect(component.to_html).to include("tw:border-[#f3c9c9]", "tw:not-disabled:not-aria-disabled:hover:bg-red-50")
    end
  end

  context "with spinner" do
    let(:options) { {text:, type: "submit", spinner: true} }

    it "renders a self-wired hidden spinner that inherits the button's text color" do
      expect(component).to have_css("button[data-controller='ui--button--submit-spinner']")
      expect(component).to have_css("span.tw\\:hidden[data-ui--button--submit-spinner-target='spinner'] svg", visible: :all)
      expect(component.css("svg").first["class"]).to_not include("tw:text-slate-400")
      expect(component).to have_text("Click me")
    end
  end

  context "with name and value" do
    let(:options) { {text:, type: "submit", name: "impound_claim[status]", value: "submitting"} }

    it "submits the value, so a second submit button can say which was pressed" do
      expect(component).to have_css("button[type='submit'][name='impound_claim[status]'][value='submitting']")
    end
  end

  it "leaves name and value off by default" do
    expect(component).to have_no_css("button[name]")
    expect(component).to have_no_css("button[value]")
  end

  context "with link color" do
    let(:color) { :link }

    it "renders link styles" do
      html = component.to_html
      expect(html).to include("twlink")
      expect(html).not_to include("tw:text-blue-600")
      expect(html).not_to include("tw:bg-blue-600")
      # Text-only, so no size padding
      expect(html).to_not include(UI::Button::Component::SIZES[:md])
    end

    context "with html_class" do
      let(:options) { {text:, color:, html_class: "tw:text-xs tw:font-bold"} }

      it "renders the passed classes alongside twlink" do
        expect(component).to have_css("button.twlink.tw\\:font-bold.tw\\:text-xs")
      end
    end

    context "with non-default size" do
      let(:size) { :lg }

      it "raises ArgumentError" do
        expect { instance }.to raise_error(ArgumentError, /size is not supported for link color/)
      end
    end
  end

  context "with secondary color" do
    let(:color) { :secondary }

    it "renders the purple outline styles" do
      expect(component.to_html).to include("tw:not-disabled:not-aria-disabled:hover:border-purple-500")
    end
  end

  context "with an unknown color" do
    let(:color) { :invalid }

    it "raises, naming the colors it takes" do
      expect { instance }.to raise_error(ArgumentError, /unknown color :invalid, expected one of: primary, secondary/)
    end
  end

  context "with disabled" do
    let(:options) { {text: "Click", disabled: true} }

    it "disables the button and applies disabled styling" do
      expect(component).to have_css("button[disabled]")
      tokens = component.css("button").first["class"].split
      expect(tokens).to include(*described_class::DISABLED_CLASSES.split)
      # With pointer events off the browser takes the cursor from underneath the button,
      # so not-allowed never renders
      expect(component.to_html).to_not include("pointer-events-none")
    end
  end

  # Which is what keeps hover off a disabled button (:disabled) and off UI::ButtonLink's
  # disabled anchor (aria-disabled), now that nothing drops their pointer events
  it "guards every hover utility against both disabled flags" do
    hovers = described_class::COLORS.values.flat_map(&:split).grep(/hover:/)
    expect(hovers).to be_present
    expect(hovers.grep_v(/\Atw:(?:dark:)?not-disabled:not-aria-disabled:hover:/)).to eq([])
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

  context "with type submit" do
    let(:options) { {text: "Submit", type: "submit"} }

    # type is the one attribute html_options replaces rather than adds to
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

    it "doesn't invoke anything" do
      expect(component).to have_no_css("button[commandfor]")
    end
  end

  context "with invoker attributes" do
    let(:options) { {text: "Open", commandfor: "settings-modal", command: "show-modal"} }

    it "passes them through" do
      expect(component).to have_css("button[commandfor='settings-modal'][command='show-modal']")
    end
  end

  context "with class in html_options" do
    let(:options) { {text: "Open", class: "tw:text-xs"} }

    # It would be dropped for the built classes, so say so rather than ignoring it
    it "raises, naming html_class" do
      expect { instance }.to raise_error(ArgumentError, /you must use the keyword arg html_class/)
    end
  end

  context "with an html_option the component doesn't know" do
    let(:options) { {text: "Search", form: "search-form"} }

    it "passes it through" do
      expect(component).to have_css("button[form='search-form']")
    end
  end

  it "always applies the active classes (inert until data-active/pressed)" do
    tokens = component.css("button").first["class"].split
    expect(tokens).to include("tw:is-active:ring-2", "tw:is-active:bg-purple-500")
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
    it "covers every color but link, prefixed with tw:is-active:" do
      expect(described_class::ACTIVE_COLORS.keys).to eq(described_class::COLORS.keys - [:link])
      described_class::ACTIVE_COLORS.each_value do |classes|
        expect(classes.split.grep_v(/\Atw:is-active:/)).to eq([])
      end
    end

    # A utility here would outrank .twlink's own is-active rule, so link color would stop
    # following the class it's built from
    it "leaves link color to .twlink" do
      expect(described_class.build_classes(color: :link, size: :md).split).to include("twlink")
        .and(satisfy { |tokens| tokens.grep(/\Atw:is-active:(?!focus:)/).empty? })
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

    # Declaration order only breaks ties between rules of equal specificity. The hovers
    # carry two :not()s, so without the same two here a pressed button renders its hover
    # color rather than its active one — and a disabled one renders the active look.
    it "carries the guards the hovers do, so it ties them on specificity" do
      selectors = stylesheet[/^@custom-variant is-active \((.*)\);/, 1]
      guards = described_class::COLORS[:secondary][/tw:((?:not-[a-z-]+:)+)hover:/, 1].split(":")
      expect(guards).to eq(%w[not-disabled not-aria-disabled])
      expect(selectors).to include(":not(:disabled)", ':not([aria-disabled="true"])')
    end
  end
end
