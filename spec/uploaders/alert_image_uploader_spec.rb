require "rails_helper"
require "carrierwave/test/matchers"

RSpec.describe AlertImageUploader do
  include CarrierWave::Test::Matchers

  context "given a non-image or invalid base image" do
    it "raises AlertImageGeneratorError" do
      stolen_record = FactoryBot.create(:stolen_record, :with_bike_image)

      image_assignment = -> do
        image_path = stolen_record.bike_main_image.image.manipulate! { |img| img }
        expect(image_path).to match(%r{tmp})
      end

      expect { image_assignment.call }.to raise_error(CarrierWave::ProcessingError)
    end
  end

  context "given a valid bike image" do
    let(:bike_with_valid_image) do
      FactoryBot.create(:stolen_bike).tap do |bike|
        FactoryBot.create(:public_image, imageable: bike, image: valid_image)
      end
    end

    let(:valid_image) { File.open(Rails.root.join("app/assets/images/pandabike.jpg"), "r") }
    after(:each) { valid_image.close }

    it "generates landscape variant" do
      stolen_record = FactoryBot.create(:stolen_record, bike: bike_with_valid_image)
      image_uploader = stolen_record.bike_main_image.image

      image_path = image_uploader.manipulate! { |img| img }
      expect(image_path).to match(%r{/tmp/cache/.+JPEG})

      image_path = image_uploader.manipulate! { |img| img.format(:png) }
      expect(image_path).to match(%r{/tmp/cache/.+PNG})

      image_path = image_uploader.manipulate! { |img| img.format(:gif) }
      expect(image_path).to match(%r{/tmp/cache/.+GIF})
    end
  end
end
