require "rails_helper"

RSpec.describe ApplicationUploader do
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
