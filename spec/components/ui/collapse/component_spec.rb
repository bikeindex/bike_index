# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Collapse::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text: "Toggle details"} }

  it "renders a collapsed trigger without a chevron" do
    expect(component).to have_css("button[data-ui--collapse-target='trigger'][data-action='mousedown->ui--collapse#press click->ui--collapse#toggle'][aria-expanded='false']", text: "Toggle details")
    expect(component).not_to have_css("[data-ui--collapse-target='chevron']")
  end

  context "with chevron" do
    let(:options) { {text: "Toggle details", chevron: true, color: :link, aria: {label: "Details"}} }

    it "renders the chevron target, keeping the passed aria" do
      expect(component).to have_css("button.twlink[aria-expanded='false'][aria-label='Details']", text: "Toggle details")
      expect(component).to have_css("button [data-ui--collapse-target='chevron'] svg")
    end
  end

  context "with a selectable label" do
    let(:options) { {text: "Toggle details", chevron: true, selectable: true, color: :link, html_class: "tw:w-full", title: "Details"} }

    it "renders a role=button span with the button's look, taking clicks and keys" do
      expect(component).to have_css("span.twlink.tw\\:w-full[role='button'][tabindex='0'][title='Details'][aria-expanded='false']" \
        "[data-ui--collapse-target='trigger'][data-action='#{described_class::ACTIONS} #{described_class::KEY_ACTIONS}']", text: "Toggle details")
      expect(component).not_to have_css("button")
    end

    it "can't be disabled, which a span has no way to be" do
      expect { described_class.new(selectable: true, disabled: true) }.to raise_error(ArgumentError)
    end
  end

  context "with a trailing chevron and a block" do
    let(:component) { render_inline(described_class.new(chevron: :trailing)) { "<em>Columns</em>".html_safe } }

    it "renders the block, then the chevron" do
      expect(component).to have_css("button > em + [data-ui--collapse-target='chevron']", text: "")
      expect(component).to have_css("button em", text: "Columns")
    end
  end
end
