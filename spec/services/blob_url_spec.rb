require "rails_helper"

RSpec.describe BlobUrl do
  # content_security_policy.rb repeats these hosts because it's evaluated before autoloading.
  # A host img-src doesn't list renders nothing at all - the browser blocks it silently.
  it "has every storage host in the CSP img-src" do
    img_src = Rails.application.config.content_security_policy.directives.fetch("img-src")
    expect(img_src).to include(described_class::STORAGE_HOST, *described_class::STORAGE_HOSTS.values)
  end

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

  describe "for_variant" do
    let(:attached) { FactoryBot.create(:public_image, :with_attached_file).reload.file }

    it "returns the blob url without a size" do
      expect(described_class.for_variant(attached)).to eq described_class.for(attached.blob)
    end

    context "cloudflare storage" do
      before do
        stub_const("BlobUrl::LOCAL_STORAGE", false)
        allow(attached.blob.service).to receive(:name).and_return(:cloudflare_production)
      end

      it "builds the deterministic variant key without querying or processing" do
        variant = attached.variant(:large)
        expect(variant).to be_a ActiveStorage::Variant # Not VariantWithRecord, i.e. track_variants is off

        expect(described_class.for_variant(attached, :large))
          .to eq "https://uploads.bikeindex.org/#{variant.key}"
        expect(variant.key).to start_with "variants/#{attached.blob.key}/"

        urls = PublicImage::VARIANTS.keys.map { described_class.for_variant(attached, it) }
        expect(urls.uniq.count).to eq PublicImage::VARIANTS.count
      end
    end
  end
end
