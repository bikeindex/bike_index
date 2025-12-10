# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::HomepageTop::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {recoveries_value:, organization_count:, recovery_displays:} }
  let(:recoveries_value) { 11_111_111 }
  let(:organization_count) { nil }
  let(:recovery_displays) { [] }

  it "renders" do
    expect(component).to have_css("div")
    expect(component).to have_text("Cities")
    expect(component).to have_text("The bike registry that works")
  end

  describe "recoveries_value" do
    it "unit tests for instance methods" do
      expect(instance.send(:recoveries_as_currency)).to eq "$11"
      expect(instance.send(:recoveries_value)).to eq "11"
      expect(instance.send(:recoveries_value_symbol)).to eq "$"
    end
  end
end
