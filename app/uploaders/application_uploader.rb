class ApplicationUploader < CarrierWave::Uploader::Base
  IMAGE_EXT_WHITE_LIST = %w[jpg jpeg gif png tiff tif].freeze

  def self.extensions
    IMAGE_EXT_WHITE_LIST
  end

  def self.permitted_extensions
    extensions.map { |i| ".#{i}" }
  end

  def self.permitted_extensions_display
    permitted_extensions - [".jpg", ".tif"]
  end

  # Smallest version to preview an upload with -- uploaders don't share version names.
  # nil means there's nothing smaller than the original.
  def self.thumbnail_version
    %i[thumb small medium].find { versions.key?(it) }
  end

  after :remove, :delete_empty_upstream_dirs

  # Carrierwave asks storage whether the object exists, which with fog is a HEAD request -
  # paid by every mount validator and every `#{column}?`. A file is only retrieved when the
  # column held an identifier, so remotely that's answer enough. File storage stays exact.
  def blank?
    return super if cached? || _storage.to_s != "CarrierWave::Storage::Fog"

    file.nil?
  end

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "uploads/#{model_abbr}"
  end

  def delete_empty_upstream_dirs
    path = ::File.expand_path(store_dir, root)
    Dir.delete(path) # fails if path not empty dir

    path = ::File.expand_path(base_store_dir, root)
    Dir.delete(path) # fails if path not empty dir
  rescue SystemCallError
    true # nothing, the dir is not empty
  end

  private

  def model_abbr
    if defined?(model.class.uploader_abbr)
      model.class.uploader_abbr
    else
      model.class.to_s[0, 2]
    end
  end
end
