class ImageUploaderBackgrounded < ImageUploader
  include ::CarrierWave::Backgrounder::Delay
end
