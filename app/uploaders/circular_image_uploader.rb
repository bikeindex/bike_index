# encoding: utf-8

class CircularImageUploader < CarrierWave::Uploader::Base
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

  def filename
    "recovery_#{model.id}.png"
  end


  process :fix_exif_rotation
  process :strip # Remove EXIF data, because we don't need it
  process :convert => 'jpg'
  
  # def default_url
  #   'https://files.bikeindex.org/blank.png'
  # end  

  version :large do
    process :round_image
  end

  version :medium, :from_version => :large do
    process resize_to_fill: [400, 400]
  end

  version :thumb, :from_version => :medium do
    process resize_to_fill: [100,100]
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  def round_image
    manipulate! do |img|

      path = img.path

      new_tmp_path = File.join(Rails.root, 'tmp/uploads', "/round_#{File.basename(path)}")

      width, height = img[:dimensions]

      radius_point = ((width > height) ? [width / 2, height] : [width, height / 2]).join(',')

      imagemagick_command = ['convert',
                           "-size #{ width }x#{ height }",
                           'xc:transparent',
                           "-fill #{ path }",
                           "-draw 'circle #{ width / 2 },#{ height / 2 } #{ radius_point }'",
                           "+repage #{new_tmp_path}"].join(' ')

      system(imagemagick_command)
      MiniMagick::Image.open(new_tmp_path)
    end
  end



end