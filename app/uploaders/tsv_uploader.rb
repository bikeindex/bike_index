class TsvUploader < ApplicationUploader
  def store_dir
    "#{base_store_dir}tsvs"
  end

  def base_store_dir
    "uploads/"
  end
end
