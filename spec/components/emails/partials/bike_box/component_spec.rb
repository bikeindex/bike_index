# frozen_string_literal: true

require "rails_helper"

RSpec.describe Emails::Partials::BikeBox::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:, ownership:, bike_url_path:)) }
  let(:bike_url_path) { "/bikes/123?t=token" }

  context "non-stolen bike" do
    let(:ownership) { FactoryBot.create(:ownership_claimed) }
    let(:bike) { ownership.bike }
    it "renders bike info" do
      expect(component).to have_css("table.bike-display")
      expect(component).to have_content("Make:")
      expect(component).to have_content("Serial:")
      expect(component).to have_content("Color")
      expect(component).to_not have_content("Stolen from:")
      expect(component).to_not have_content("Stolen at:")
    end
  end

  context "stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
    let(:ownership) { bike.current_ownership }
    it "renders stolen info" do
      expect(bike.current_stolen_record).to be_present
      expect(component).to have_css("table.bike-display")
      expect(component).to have_content("Stolen from:")
      expect(component).to have_content("Stolen at:")
    end
  end

  context "organized bike" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
    let(:ownership) { bike.current_ownership }
    it "renders bike info" do
      expect(component).to have_css("table.bike-display")
      expect(component).to have_content("Make:")
      expect(component).to have_content(bike.mnfg_name)
    end
  end

  context "bike with thumb url" do
    let(:ownership) { FactoryBot.create(:ownership_claimed) }
    let(:bike) do
      ownership.bike.tap { |b| b.update_column(:thumb_path, "https://example.com/thumb.jpg") }
    end
    it "renders without placeholder class" do
      expect(bike.thumb_path).to eq("https://example.com/thumb.jpg")
      expect(component).to have_css("table.bike-display")
      expect(component).to have_css("td.image-holder")
      expect(component).to_not have_css("td.image-holder.placeholder")
      expect(component).to have_css("img[src='https://example.com/thumb.jpg']")
    end
  end

  context "bike without thumb url" do
    let(:ownership) { FactoryBot.create(:ownership_claimed) }
    let(:bike) { ownership.bike }
    it "renders with placeholder class and default image" do
      expect(bike.thumb_path).to be_blank
      expect(component).to have_css("td.image-holder.placeholder")
      expect(component).to have_css("img[src='https://files.bikeindex.org/email_assets/bike_photo_placeholder.png']")
    end
  end
end
