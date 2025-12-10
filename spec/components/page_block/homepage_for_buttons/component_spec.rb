# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::HomepageForButtons::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {} }

  it "renders" do
    expect(component).to have_css("div")
    expect(component).to have_text("Bike Shops")
    expect(component).to have_text("Schools")
    expect(component).to have_text("Theft Victims")
  end

  context "with skip_theft" do
    let(:options) { {skip_theft: true} }
    it "renders" do
      expect(component).to be_present
      expect(component).to have_css("div")
      expect(component).to have_text("Bike Shops")
      expect(component).to have_text("Schools")
      expect(component).to_not have_text("Theft Victims")
    end
  end
end
