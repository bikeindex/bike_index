class BulkImportUploader < ApplicationUploader
  def store_dir
    "#{base_store_dir}imports/#{model.id}"
  end

  def base_store_dir
    "uploads/"
  end
end
