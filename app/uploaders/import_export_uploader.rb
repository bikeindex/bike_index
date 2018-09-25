# encoding: utf-8

class ImportExportUploader < CarrierWave::Uploader::Base
   if Rails.env.test?
    storage :file
  elsif Rails.env.development?
    storage :file
  else
    storage :fog
  end

  def store_dir
    "#{base_store_dir}import_exports"
  end

  def base_store_dir
    "uploads/"
  end

  def extension_white_list
    %w(csv tsv xls xlsx)
  end
end
