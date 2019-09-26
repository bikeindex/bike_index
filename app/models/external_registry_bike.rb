class ExternalRegistryBike < ActiveRecord::Base
  belongs_to :external_registry

  validates \
    :external_id,
    :external_registry,
    :serial_number,
    presence: true

  # :category
  # :date_stolen
  # :description
  # :frame_colors
  # :frame_model
  # :image_url
  # :is_stock_img
  # :large_img
  # :location_found
  # :mnfg_name
  # :source_name
  # :source_unique_id
  # :status
  # :thumb
  # :thumb_url
  # :type
  # :url

  def stolen
    status&.downcase == "stolen"
  end

  def title_string
    "#{mnfg_name} #{frame_model}"
  end

  def mnfg_name
    self[:mnfg_name]&.titleize
  end

  def frame_model
    self[:frame_model]&.titleize
  end

  def frame_colors
    self[:frame_colors]&.split(/\s*,\s*/)&.to_a&.map(&:titleize)
  end

  def source_name
    self[:source_name]&.titleize
  end

  def status
    self[:status]&.titleize
  end
end
