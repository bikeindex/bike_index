class PdfUploader < ApplicationUploader
  include ::CarrierWave::Backgrounder::Delay

  def extension_white_list
    IMAGE_EXT_WHITE_LIST + ["pdf"]
  end
end
