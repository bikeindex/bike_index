# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::IconSorting::Component, type: :component do
  it "renders a down arrow for desc" do
    expect(render_inline(described_class.new(direction: "desc")).text).to eq("↓")
  end

  it "renders an up arrow for asc" do
    expect(render_inline(described_class.new(direction: "asc")).text).to eq("↑")
  end

  it "falls back to a down arrow for an unknown direction" do
    expect(render_inline(described_class.new(direction: "sideways")).text).to eq("↓")
  end
end
