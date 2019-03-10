# encoding: utf-8

class AvatarUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
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

  # Fallback so the page doesn't break if the image isn't there
  def default_url
    'https://files.bikeindex.org/blank.png'
  end

  def cache_dir
    Rails.root.join("tmp", "cache")
  end

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end
  
  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

  process :validate_dimensions

  def extension_white_list
    %w(jpg jpeg gif png)
  end

  def auto_orient
    manipulate! do |img|
      img = img.auto_orient
    end
  end


  version :thumb do
    process :auto_orient
    process resize_to_fill: [100, 100]
  end

  version :medium do
    process :auto_orient
    process resize_to_fill: [300, 300]
  end

  version :large do
    process :auto_orient
    process resize_to_fill: [600, 600]
  end

  version :biggest do
    process :auto_orient
    process resize_to_fill: [1000, 1000]
  end
end
