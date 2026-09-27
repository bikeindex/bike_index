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

    it "puts the label beside a chevron-only button that it names, with the row taking the clicks and the button's look" do
      label_id = component.at_css("span.tw\\:contents")["id"]

      expect(component).to have_css("span.twlink.tw\\:w-full[data-ui--collapse-target='row'][data-action='mousedown->ui--collapse#press click->ui--collapse#toggle'] > " \
        "button[aria-labelledby='#{label_id}'][aria-expanded='false'][title='Details']:not([data-action]) + span.tw\\:contents[aria-hidden='true']", text: "Toggle details")
      expect(component).not_to have_css("button", text: "Toggle details")
    end

    context "disabled" do
      let(:options) { {text: "Toggle details", selectable: true, color: :link, disabled: true} }

      it "disables the button, and leaves the row without the click" do
        expect(component).to have_css("span[data-ui--collapse-target='row']:not([data-action]) > button[disabled]")
      end
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
