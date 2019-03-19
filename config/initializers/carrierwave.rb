# Configure carrierwave

CarrierWave.configure do |config|
  config.cache_dir = "#{Rails.root}/tmp/uploads"
  config.storage = :fog # For some reason, uploading sitemap doesn't work unless this is included.
  config.asset_host = "https://files.bikeindex.org" if Rails.env.production?
  config.fog_credentials = {
    provider: "AWS",
    aws_access_key_id: ENV["S3_ACCESS_KEY"],
    aws_secret_access_key: ENV["S3_SECRET_KEY"],
    region: "us-east-1"

  }
  config.fog_directory = ENV["S3_BUCKET"]
  config.fog_attributes = { "Cache-Control" => "max-age=315576000" }
end

# Monkey Patch carrierwave
module CarrierWave
  module MiniMagick
    # check for images that are too large
    def validate_dimensions
      manipulate! do |img|
        if img.dimensions.any?{|i| i > 8000 }
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
