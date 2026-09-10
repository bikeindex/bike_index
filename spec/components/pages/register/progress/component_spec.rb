# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Progress::Component, type: :component do
  let(:component) { render_inline(described_class.new(steps: %w[1 2 report], step:)) }

  context "a step in the list" do
    let(:step) { 2 }

    it "renders a segment per step, filling the completed ones" do
      expect(component.css("span").count).to eq 3
      expect(component.to_html.scan("tw:bg-purple-500").count).to eq 2
    end
  end

  # The report shifts the steps after it, so its own place is whatever the list says
  context "the report step" do
    let(:step) { "report" }

    it "counts from the list rather than the step's name" do
      expect(component.to_html.scan("tw:bg-purple-500").count).to eq 3
    end
  end
end
