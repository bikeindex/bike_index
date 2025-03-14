require "rails_helper"
require "carrierwave/test/matchers"

RSpec.describe ImageUploader do
  include CarrierWave::Test::Matchers

  describe "permitted_extensions" do
    let(:target) { [".jpg", ".jpeg", ".gif", ".png", ".tiff", ".tif"] }
    let(:target_display) { [".jpeg", ".gif", ".png", ".tiff"] }
    it "is expected" do
      expect(ImageUploader.permitted_extensions).to eq target
      expect(ImageUploader.permitted_extensions_display).to eq target_display
    end
  end

  # TODO: Test this!

  # before do
  #   ImageUploader.enable_processing = true
  #   @uploader = ImageUploader.new(@user, :avatar)
  #   @uploader.store!(File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg')))
  # end

  # after do
  #   MyUploader.enable_processing = false
  #   @uploader.remove!
  # end

  # Commented out in #2727 because the github spec formatter highlights pending
  # context "the small version" do
  #   xit "scales down a landscape image to be exactly 64 by 64 pixels" do
  #     expect(@uploader.large).to be_no_larger_than(1200, 900)
  #   end
  # end

  # context "the small version" do
  #   xit "scales down a landscape image to fit within 200 by 200 pixels" do
  #     expect(@uploader.medium).to be_no_larger_than(700, 525)
  #   end
  # end
  # context "the small version" do
  #   xit "scales down a landscape image to fit within 200 by 200 pixels" do
  #     expect(@uploader.small).to have_dimensions(300, 300)
  #   end
  # end
end
