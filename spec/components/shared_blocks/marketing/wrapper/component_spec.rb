# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::Wrapper::Component, type: :component do
  let(:page) { SharedBlocks::Marketing::CallToActionBanner::Component.new(heading: "Members keep it free") }
  let(:component) { render_inline(described_class.new(page:)) }

  it "renders the page inside the full-bleed shell" do
    expect(component.css("div.tw\\:-mb-18 h2").text).to match "Members keep it free"
  end
end
