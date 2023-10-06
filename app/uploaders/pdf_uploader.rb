class PdfUploader < ApplicationUploader
  include ::CarrierWave::Backgrounder::Delay
end
