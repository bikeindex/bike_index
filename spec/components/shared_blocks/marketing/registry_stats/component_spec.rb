# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::RegistryStats::Component, type: :component do
  let(:component) { render_inline(described_class.new) }
  let(:total_bikes) { 999_999 }

  before do
    Counts.assign_for("total_bikes", total_bikes)
    Counts.assign_for("recoveries", 18_263)
    Counts.assign_for("recoveries_value", 38_412_345)
    Counts.assign_for("organizations", 1_234)
  end

  it "renders every figure" do
    expect(component.css("dd").map { it.text.strip }).to eq(["999,999", "18,263", "$38M+", "1,200+"])
  end

  context "with over a million bikes" do
    let(:total_bikes) { 1_199_999 }

    it "floors the count to a tenth of a million" do
      expect(component).to have_text("1.1M+")
    end
  end
end
