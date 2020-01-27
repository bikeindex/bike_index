class PdfUploader < ApplicationUploader
  include ::CarrierWave::Backgrounder::Delay

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end
end
