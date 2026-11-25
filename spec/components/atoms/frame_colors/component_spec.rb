# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::FrameColors::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:)) }
  let(:bike) { FactoryBot.create(:bike, secondary_frame_color: FactoryBot.create(:color, name: "Blue")) }

  it "renders a swatch per color, then the names" do
    expect(component).to have_text("Black / Blue")
    expect(component).to have_css("span.tw\\:flex.tw\\:gap-0\\.5 > *", count: 2)
  end
end
