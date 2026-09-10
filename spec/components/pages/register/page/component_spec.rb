# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Page::Component, type: :component do
  let(:component) { render_inline(described_class.new) { "page content" } }

  it "renders the content inside the centered shell" do
    expect(component).to have_text "page content"
    expect(component.to_html).to include "tw:max-w-md"
    expect(component.to_html).to include "tw:bg-gray-100"
  end

  context "embed" do
    let(:component) { render_inline(described_class.new(embed: true)) { "page content" } }

    it "renders the content without the gray shell around it" do
      expect(component).to have_text "page content"
      expect(component.to_html).to_not include "tw:bg-gray-100"
    end
  end
end
