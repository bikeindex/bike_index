require "rails_helper"

RSpec.describe BlobUrl do
  describe "for" do
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images) }
    it "returns the url" do
      expect(stolen_record.reload.images_attached?).to be_truthy

      expect(described_class.for(stolen_record.image_four_by_five))
        .to eq Rails.application.routes.url_helpers.rails_blob_url(stolen_record.image_four_by_five.blob)
    end
    context "blank" do
      it "returns nil" do
        expect(described_class.for(nil)).to be_nil
      end
    end

    context "cloudflare storage" do
      let(:blob) { stolen_record.reload.image_four_by_five.blob }
      let(:production_host) { "https://uploads.bikeindex.org" }
      let(:dev_host) { "https://dev-uploads.bikeindex.org" }

      before do
        stub_const("BlobUrl::LOCAL_STORAGE", false)
      end

      context "cloudflare_production service" do
        before do
          allow(blob.service).to receive(:name).and_return(:cloudflare_production)
        end

        it "uses ACTIVE_STORAGE_HOST" do
          expect(described_class.for(blob)).to eq "#{production_host}/#{blob.key}"
        end
      end

      context "cloudflare_dev service" do
        before do
          allow(blob.service).to receive(:name).and_return(:cloudflare_dev)
        end

        it "uses ACTIVE_STORAGE_HOST_DEV" do
          expect(described_class.for(blob)).to eq "#{dev_host}/#{blob.key}"
        end
      end
    end
  end
end
