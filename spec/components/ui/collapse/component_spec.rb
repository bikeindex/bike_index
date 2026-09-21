# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Collapse::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text: "Toggle details"} }

  it "renders a collapsed trigger without a chevron" do
    expect(component).to have_css("button[data-ui--collapse-target='trigger'][data-action='ui--collapse#toggle'][aria-expanded='false']", text: "Toggle details")
    expect(component).not_to have_css("[data-ui--collapse-target='chevron']")
  end

  context "with chevron and expanded" do
    let(:options) { {text: "Toggle details", chevron: true, expanded: true, color: :link, aria: {label: "Details"}} }

    it "renders an open trigger with a rotated chevron, keeping the passed aria" do
      expect(component).to have_css("button.twlink[aria-expanded='true'][aria-label='Details']", text: "Toggle details")
      expect(component).to have_css("button [data-ui--collapse-target='chevron'].tw\\:rotate-90 svg")
    end
  end
end
