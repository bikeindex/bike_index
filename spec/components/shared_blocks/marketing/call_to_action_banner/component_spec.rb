# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::CallToActionBanner::Component, type: :component do
  let(:options) { {heading: "Members keep it free"} }
  let(:component) { render_inline(described_class.new(**options)) { "<a href='/join'>Join</a>".html_safe } }

  it "renders the heading, illustration and action" do
    expect(component.css("h2").text).to match "Members keep it free"
    expect(component.css("img").count).to eq 1
    expect(component.css("a[href='/join']").count).to eq 1
    expect(component.css("p").count).to eq 0
  end

  context "with a subheading and no illustration" do
    let(:options) { super().merge(subheading: "It takes three minutes", illustration: false) }

    it "renders the subheading and no image" do
      expect(component.css("p").text).to match "It takes three minutes"
      expect(component.css("img").count).to eq 0
    end
  end
end
