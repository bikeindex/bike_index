# encoding: utf-8

class PdfUploader < CarrierWave::Uploader::Base
  include ::CarrierWave::Backgrounder::Delay
  include CarrierWave::MimeTypes

  process :set_content_type
  # include Sprockets::Helpers::RailsHelper # Deprecated. Should be removed
  # include Sprockets::Helpers::IsolatedHelper # Deprecated. Should be removed

  if Rails.env.test?
    storage :file
  elsif Rails.env.development?
    storage :file
  else
    storage :fog
  end
  
  after :remove, :delete_empty_upstream_dirs  
  def delete_empty_upstream_dirs
    path = ::File.expand_path(store_dir, root)
    Dir.delete(path) # fails if path not empty dir
    
    path = ::File.expand_path(base_store_dir, root)
    Dir.delete(path) # fails if path not empty dir
  rescue SystemCallError
    true # nothing, the dir is not empty
  end

  def cache_dir
    Rails.root.join("tmp", "uploads", "cache")
  end

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end
  
  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

end
