# encoding: utf-8

class TsvUploader < CarrierWave::Uploader::Base
  # Include the Sprockets helpers for Rails 3.1+ asset pipeline compatibility:
  include Sprockets::Helpers::RailsHelper
  include Sprockets::Helpers::IsolatedHelper
 
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
