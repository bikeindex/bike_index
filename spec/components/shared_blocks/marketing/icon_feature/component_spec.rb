# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::IconFeature::Component, type: :component do
  let(:options) { {icon: "icons/searcher.svg", circle: "tw:bg-blue-600", title: "Free registration", body: "It costs nothing"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders the icon, title and body" do
    expect(component.css("span.tw\\:bg-blue-600 svg").count).to eq 1
    expect(component.css("h3").text).to match "Free registration"
    expect(component.css("p").text).to match "It costs nothing"
    expect(component.css("div.tw\\:rounded-lg").count).to eq 0
  end

  context "as a card" do
    let(:options) { super().merge(card: true) }

    it "renders boxed" do
      expect(component.css("div.tw\\:rounded-lg").count).to eq 1
    end
  end
end
