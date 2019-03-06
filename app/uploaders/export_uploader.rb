# encoding: utf-8

# We really should obfuscate the filename, for this and bulk imports
class ExportUploader < CarrierWave::Uploader::Base
  if Rails.env.test?
    storage :file
  elsif Rails.env.development?
    storage :file
  else
    storage :fog
  end

  def cache_dir
    Rails.root.join("tmp", "cache")
  end

  def store_dir
    "#{base_store_dir}exports/#{model.id}"
  end

  def base_store_dir
    "uploads/"
  end

  def extension_white_list
    %w(csv tsv xls xlsx)
  end
end
