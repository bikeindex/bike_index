# encoding: utf-8

class PartnerUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  if Rails.env.production?
    storage :fog
  else
    storage :file
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
    Rails.root.join("tmp", "cache")
  end

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end
  
  def base_store_dir
    "partner/"
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff)
  end

  process :fix_exif_rotation
  process :strip

  version :large do
    process resize_to_fill: [600, 200]
  end

  version :medium, from_version: :large do
    process resize_to_fit: [300,100]
  end

  version :small, from_version: :medium do
    process resize_to_fill: [100,100]
  end

end
