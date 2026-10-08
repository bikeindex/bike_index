# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::EbikeRules::LawDetails::Component, type: :component do
  before { stub_bikebook_catalog }

  let(:today) { Date.new(2026, 10, 8) }
  let(:component) { render_inline(described_class.new(law: EbikeRules::StateLaws.find(abbreviation, today:))) }

  context "with rules still to come" do
    let(:abbreviation) { "CA" }

    it "marks each with the days it runs, and the rest without" do
      expect(component).to have_css("li", text: /\A\s*From January 1, 2027 until January 1, 2031:\s+Cities in San Mateo County may bar riders under 12/)
        .and have_css("li", text: /\A\s*From January 1, 2029:\s+Every new Class 2 must have a speedometer/)
        .and have_css("li", text: /\A\s*Fully operable pedals and an electric motor/)
        .and have_no_text("take effect")
    end
  end

  context "with limits not yet in force" do
    let(:abbreviation) { "NC" }

    it "says when they take effect, beside the rule that applies until then" do
      expect(component).to have_text("These limits take effect December 1, 2026. Until then, the rules below say what applies.")
        .and have_css("li", text: /\A\s*Until December 1, 2026:\s+Its top speed on motor power alone on level ground is 20 mph/)
    end
  end
end
