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
  config.cache_dir = Rails.root.join("tmp", "uploads")
  config.storage :file
  config.asset_host = ENV["BASE_URL"]

  if Rails.env.production?
    # config.fog_provider "fog/aws" # Once carrierwave is updated
    config.storage = :fog
    config.asset_host = ENV["S3_ASSET_HOST"]
    config.fog_credentials = {
      provider: "AWS",
      aws_access_key_id: ENV["S3_ACCESS_KEY"],
      aws_secret_access_key: ENV["S3_SECRET_KEY"],
      region: "us-east-1",
    }
    config.fog_directory = ENV["S3_BUCKET"]
    config.fog_attributes = { "Cache-Control" => "max-age=315576000" }
    config.storage :fog
  end
end
