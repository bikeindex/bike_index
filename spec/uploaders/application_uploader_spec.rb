require "rails_helper"

RSpec.describe ApplicationUploader do
  # An instance-level cache_dir override shadows CarrierWave's config silently, which is how
  # every parallel worker came to cache into one shared directory -- and not the per-worker one
  # rails_helper creates and clears between example groups
  describe "cache_dir" do
    let(:uploader) { described_class.new(PublicImage.new, :image) }

    it "caches into the configured per-worker directory" do
      expect(described_class.cache_dir.to_s).to end_with "carrierwave#{ENV["TEST_ENV_NUMBER"]}"
      uploader.cache!(File.open(Rails.root.join("spec", "fixtures", "bike.jpg")))
      expect(uploader.file.path).to start_with "#{described_class.cache_dir}/"
    end
  end

  # Only production stores with fog, so this builds the storage the app can't exercise
  # otherwise. There are no fog_credentials in test, so reaching for the connection raises -
  # which is the assertion: `blank?` has to answer without asking S3.
  describe "blank? with fog storage" do
    let(:uploader_class) do
      Class.new(ApplicationUploader) { storage :fog }
    end
    let(:uploader) { uploader_class.new(PublicImage.new, :image) }

    it "is false for a stored file, without a request" do
      uploader.retrieve_from_store!("bike.jpg")
      expect(uploader.blank?).to be_falsey
    end

    it "is true without a file" do
      expect(uploader.blank?).to be_truthy
    end
  end
end
