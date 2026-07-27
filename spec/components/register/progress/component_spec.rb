# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::Progress::Component, type: :component do
  let(:component) { render_inline(described_class.new(step: 2, total: 3)) }

  it "renders a segment per step, filling the completed ones" do
    expect(component.css("span").count).to eq 3
    expect(component.to_html.scan("tw:bg-[#715eb2]").count).to eq 2
  end
end
