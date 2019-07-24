# encoding: utf-8
class TsvUploader < CarrierWave::Uploader::Base
  def cache_dir
    Rails.root.join("tmp", "cache")
  end

  def store_dir
    "#{base_store_dir}tsvs"
  end

  def base_store_dir
    "uploads/"
  end
end
