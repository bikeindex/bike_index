# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Collapse::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {text: "Toggle details"} }

  it "renders a collapsed trigger without a chevron" do
    expect(component).to have_css("span[role='button'][tabindex='0'][aria-expanded='false'][data-ui--collapse-target='trigger']", text: "Toggle details")
    expect(component).not_to have_css("[data-ui--collapse-target='chevron']")
  end

  context "with chevron" do
    let(:options) { {text: "Toggle details", chevron: true, color: :link, html_class: "tw:w-full", title: "Details", aria: {label: "Details"}} }

    it "renders the chevron target with the button's look, keeping the passed aria" do
      expect(component).to have_css("span.twlink.tw\\:w-full[title='Details'][aria-expanded='false'][aria-label='Details']", text: "Toggle details")
      expect(component).to have_css("[role='button'] [data-ui--collapse-target='chevron'] svg")
    end
  end

  context "with a trailing chevron and a block" do
    let(:component) { render_inline(described_class.new(chevron: :trailing)) { "<em>Columns</em>".html_safe } }

    it "renders the block, then the chevron" do
      expect(component).to have_css("[role='button'] > em + [data-ui--collapse-target='chevron']")
      expect(component).to have_button("Columns")
    end
  end
end
