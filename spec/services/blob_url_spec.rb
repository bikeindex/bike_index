require "rails_helper"

RSpec.describe BlobUrl do
  describe "for" do
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images) }
    it "returns the url" do
      expect(stolen_record.reload.images_attached?).to be_truthy

      expect(described_class.for(stolen_record.image_four_by_five))
        .to eq Rails.application.routes.url_helpers.rails_blob_url(stolen_record.image_four_by_five.blob)
    end
  end
end
