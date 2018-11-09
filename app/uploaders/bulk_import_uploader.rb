# encoding: utf-8

class BulkImportUploader < ExportUploader
  def store_dir
    "#{base_store_dir}imports/#{model.id}"
  end
end
