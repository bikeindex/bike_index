require 'yaml'

CarrierWave.configure do |config|
  config.cache_dir = "#{Rails.root}/tmp/uploads"
  config.storage = :fog # For some reason, uploading sitemap doesn't work unless this is included.
  config.asset_host = 'https://files.bikeindex.org' unless Rails.env.development?
  config.fog_credentials = {
    provider:               'AWS',       # required
    aws_access_key_id:      ENV['S3_ACCESS_KEY'],
    aws_secret_access_key:  ENV['S3_SECRET_KEY'],
    region:                 'us-east-1'  # optional, defaults to 'us-east-1'

  }
  config.fog_directory  = ENV['S3_BUCKET']
  config.fog_attributes = {'Cache-Control'=>'max-age=315576000'} 
end
