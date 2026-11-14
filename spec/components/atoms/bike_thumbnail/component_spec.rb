# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::BikeThumbnail::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:)) }

  context "with a photo" do
    let(:bike) { Bike.new(thumb_path: "https://files.bikeindex.org/uploads/small_bike.jpeg") }

    it "renders the image" do
      expect(component).to have_css("img[src='https://files.bikeindex.org/uploads/small_bike.jpeg'][loading='lazy']")
    end
  end

  context "without a photo" do
    let(:bike) { nil }

    it "renders a blank tile" do
      expect(component).to have_no_css("img")
      expect(component).to have_css("span.tw\\:bg-gray-100")
    end
  end
end
