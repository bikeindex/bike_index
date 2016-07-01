# encoding: utf-8

class ListicleImageUploader < CarrierWave::Uploader::Base
  include ::CarrierWave::Backgrounder::Delay
  include CarrierWave::MiniMagick
  # include Sprockets::Helpers::RailsHelper # Deprecated. Should be removed
  # include Sprockets::Helpers::IsolatedHelper # Deprecated. Should be removed
 
  if Rails.env.test? || Rails.env.development?
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

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end
  
  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

  process :fix_exif_rotation
  process :strip # Remove EXIF data, because we don't need it

  version :at_width do
    process resize_to_fit: [726, 10000]
  end

  version :large, :from_version => :at_width do
    process :crop
  end

  version :medium, :from_version => :large do
    process resize_to_fill: [300, 300]
  end

  version :thumb, :from_version => :medium do
    process resize_to_fill: [100,100]
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  def crop
    # resize_to_fit(726, 10000)
    manipulate! do |img|
      x = 0
      y = model.crop_top_offset.to_i
      w = 726
      h = 450
      img.crop "#{w}x#{h}+#{x}+#{y}"
      img
    end
  end

end