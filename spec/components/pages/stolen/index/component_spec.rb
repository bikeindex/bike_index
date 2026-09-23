# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Stolen::Index::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {recoveries_count: 18_263, recoveries_value: 38_412_345, organizations_count: 1_000, recovery_displays:} }
  let(:recovery_displays) { [] }

  it "renders the steps and stats" do
    expect(component).to have_css("h1", text: "Your bike is gone.")
    expect(component).to have_css("ol > li", count: 6)
    expect(component).to have_link("Set up Google Alerts", href: "https://www.google.com/alerts")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38.4M")
    expect(component).to have_text("1,000+")
    expect(component).to have_css("details[open]", count: 1)
    expect(component).to have_css("details[name='stolen-faq']", count: 5)
  end

  context "with more recovery displays than it shows" do
    let(:recovery_displays) do
      Array.new(5) { |i| FactoryBot.build(:recovery_display, quote: "Quote #{i}", quote_by: "Owner #{i}") }
    end

    it "renders the first four, hiding the last two on mobile" do
      expect(component).to have_css("ul > li blockquote", count: 4)
      expect(component).to have_text("Quote 3")
      expect(component).to_not have_text("Quote 4")
      expect(component).to have_css("li.tw\\:hidden blockquote", count: 2)
    end
  end
end
