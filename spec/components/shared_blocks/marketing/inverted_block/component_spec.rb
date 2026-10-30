# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::InvertedBlock::Component, type: :component do
  let(:component) { render_inline(described_class.new) { "<p>Partner with us</p>".html_safe } }

  it "renders the content inside an inverted section" do
    expect(component.css("section.inverted p").text).to eq "Partner with us"
  end
end
