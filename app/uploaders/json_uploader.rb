class JsonUploader < ApplicationUploader
  def store_dir
    "#{base_store_dir}json"
  end

  def base_store_dir
    "uploads/"
  end
end
