# Monkey Patch carrierwave
module CarrierWave
  module MiniMagick
    # check for images that are too large
    def validate_dimensions
      manipulate! do |img|
        if img.dimensions.any? { |i| i > 8000 }
          raise CarrierWave::ProcessingError, "dimensions too large"
        end
        img
      end
    end

    # Rotates the image based on the EXIF Orientation
    def fix_exif_rotation
      manipulate! do |img|
        img.auto_orient
        img = yield(img) if block_given?
        img
      end
    end

    # Strips out all embedded information from the image
    def strip
      manipulate! do |img|
        img.strip
        img = yield(img) if block_given?
        img
      end
    end
  end
end

# Additional carrierwave configurations
CarrierWave.configure do |config|
  config.asset_host = ActionController::Base.asset_host
  config.cache_dir = Rails.root.join("tmp", "uploads")
  config.storage :file

  if Rails.env.production?
    # config.fog_provider "fog/aws" # Once carrierwave is updated
    config.storage = :fog
    config.fog_credentials = {
      provider: "AWS",
      aws_access_key_id: ENV["S3_ACCESS_KEY"],
      aws_secret_access_key: ENV["S3_SECRET_KEY"],
      region: "us-east-1",
    }
    config.fog_directory = ENV["S3_BUCKET"]
    config.fog_attributes = { "Cache-Control" => "max-age=315576000" }
    config.storage :fog
  elsif Rails.env.test?
    config.cache_dir = Rails.root.join("tmp", "cache", "carrierwave#{ENV["TEST_ENV_NUMBER"]}")
    config.enable_processing = false
  end
end

RSpec.configure do |config|
  config.before(:all) do
    FileUtils.mkdir_p(ApplicationUploader.cache_dir)
  end

  config.after(:all) do
    FileUtils.rm_rf(ApplicationUploader.cache_dir)
    FileUtils.mkdir_p(ApplicationUploader.cache_dir)
  end
end
