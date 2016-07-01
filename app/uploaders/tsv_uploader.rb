# encoding: utf-8
class TsvUploader < CarrierWave::Uploader::Base
  # include Sprockets::Helpers::RailsHelper # Deprecated. Should be removed
  # include Sprockets::Helpers::IsolatedHelper # Deprecated. Should be removed
 
  if Rails.env.test?
    storage :file
  elsif Rails.env.development?
    storage :file
  else
    storage :fog
  end

  def store_dir
    "#{base_store_dir}tsvs"
  end
  
  def base_store_dir
    "uploads/"
  end

end
