# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::CurrencyMillions::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {dollars_usd: 38_412_345} }

  it "floors to whole millions" do
    expect(component).to have_css("span", exact_text: "$38M+")
    expect(component).to_not have_css("[data-controller]")
  end

  context "under a million" do
    let(:options) { {dollars_usd: 450_000} }

    it "renders the whole amount" do
      expect(component).to have_css("span", exact_text: "$450,000+")
    end
  end

  context "with a currency whose symbol follows the number" do
    let(:options) { {dollars_usd: 38_412_345, animate: true, currency: "SEK"} }
    before { ExchangeRate.add_rate("USD", "SEK", 10) }

    it "puts the M+ on the number, not the symbol" do
      expect(component).to have_css("span", exact_text: "384M+ kr")
      span = component.at_css("span")
      expect(span["data-homepage--animate-count-target-value"]).to eq "384"
      expect(span["data-homepage--animate-count-prefix-value"]).to eq ""
      expect(span["data-homepage--animate-count-suffix-value"]).to eq "M+ kr"
    end
  end
end
