# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::Photos::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:)) }
  let(:bike) { FactoryBot.create(:bike, year: 2025, frame_model: "Haul ST", stock_photo_url: "https://bikebook.bikeindex.org/specialized/2025/haul-st.png") }

  it "badges the stock photo with its model" do
    expect(component).to have_css("img[src='https://bikebook.bikeindex.org/specialized/2025/haul-st.png']")
    expect(component).to have_text("Stock photo of a 2025 Haul ST")
  end

  context "with a photo of its own" do
    before do
      FactoryBot.create(:public_image, imageable: bike)
      bike.reload.save
    end

    it "leads with it, the stock photo the last thumbnail" do
      expect(component).to have_no_css("img.tw\\:aspect-4\\/3[src='https://bikebook.bikeindex.org/specialized/2025/haul-st.png']")
      expect(component).to have_css("button[data-registrations--show--photos-target='thumbnail']", count: 2)
      expect(component).to have_css("li:last-child button[data-stock='true'] img[src='https://bikebook.bikeindex.org/specialized/2025/haul-st.png']")
      expect(component).to have_css("li:last-child button[aria-label='Stock photo of a 2025 Haul ST']", text: "Stock")
      # Over the large photo once the stock thumbnail is picked
      expect(component).to have_css("[data-registrations--show--photos-target='stockBadge'].tw\\:hidden", text: "Stock photo of a 2025 Haul ST")
    end
  end
end
