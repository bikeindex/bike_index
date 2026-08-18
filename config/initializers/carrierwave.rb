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
  config.cache_dir = Rails.root.join("tmp", "cache")
  config.storage = :file
  config.asset_host = ENV["BASE_URL"]

  # Real production only — sandbox doesn't provision S3_* env vars (uploads
  # fall through to local file storage; ActiveStorage uses R2).
  if Rails.env.production?
    # config.fog_provider "fog/aws" # Once carrierwave is updated
    config.storage = :fog
    config.asset_host = ENV["S3_ASSET_HOST"]
    config.fog_credentials = {
      provider: "AWS",
      aws_access_key_id: ENV["S3_ACCESS_KEY"],
      aws_secret_access_key: ENV["S3_SECRET_KEY"],
      region: "us-east-1",
      path_style: true,
      # Excon defaults to 60s and fog to 5 retries, so an unreachable S3 outlasts rack-timeout's
      # 30s and the request 500s. Worst case here is 3 connects + 2 intervals = 17s
      connection_options: {connect_timeout: 5, read_timeout: 10, write_timeout: 10, retry_limit: 2}
    }
    config.fog_directory = ENV["S3_BUCKET"]
    config.fog_attributes = {"Cache-Control" => "max-age=315576000"}
  end
end

CarrierWave::Backgrounder.configure do |c|
  c.backend :sidekiq, queue: :med_priority, retry: 2
end
