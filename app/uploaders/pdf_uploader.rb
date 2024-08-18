class PdfUploader < ApplicationUploader
  def self.extensions
    IMAGE_EXT_WHITE_LIST + ["pdf"]
  end

  def extension_allowlist
    self.class.extensions
  end
end
