# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::IconChevron::Component, type: :component do
  it "renders a chevron svg carrying the passed class" do
    render_inline(described_class.new(html_class: "tw:size-4 tw:transition-transform"))

    svg = page.find("svg", visible: :all)
    expect(svg[:class]).to eq "tw:size-4 tw:transition-transform"
    expect(page).to have_css("svg path[d='m6 9 6 6 6-6']", visible: :all)
    # SVG viewBox is case-sensitive; content_tag must preserve it
    expect(rendered_content).to include('viewBox="0 0 24 24"')
  end
end
