# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::StockPhotoBadge::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:, display:)) }
  let(:display) { :full }
  let(:bike) { Bike.new(year: 2025, frame_model: "Sneak Plus EQ MidStep", stock_photo_url:, thumb_path:) }
  let(:stock_photo_url) { "https://bikebook.bikeindex.org/aventon/2025/sneak.jpg" }
  let(:thumb_path) { "https://files.bikeindex.org/uploads/small_bike.jpeg" }
  let(:description) { "Stock photo of a 2025 Sneak Plus EQ MidStep" }

  it "names the model, with no tooltip, whatever photos it has of its own" do
    expect(component).to have_text(description)
    expect(component).to have_no_css("[role='tooltip']", visible: :all)
  end

  context "as a word" do
    let(:display) { :word }

    it "is the tooltip's trigger" do
      expect(component).to have_css("button[aria-label='#{description}']", text: "Stock")
      expect(component).to have_css("[role='tooltip']", text: description, visible: :all)
    end
  end

  context "small" do
    let(:display) { :small }

    it "is the tooltip's trigger" do
      expect(component).to have_css("button[aria-label='#{description}']", exact_text: "Stock")
    end
  end

  context "without a stock photo" do
    let(:stock_photo_url) { nil }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
