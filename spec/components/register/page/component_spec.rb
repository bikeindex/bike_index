# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::Page::Component, type: :component do
  let(:component) { render_inline(described_class.new) { "page content" } }

  it "renders the content inside the centered shell" do
    expect(component).to have_text "page content"
    expect(component.to_html).to include "tw:max-w-md"
  end
end
