class ExternalRegistryBike < ApplicationRecord
  belongs_to :country, class_name: "Country"

  validates \
    :country,
    :external_id,
    :serial_number,
    :serial_normalized,
    presence: true

  validates :external_id, uniqueness: {scope: :type}

  before_validation :set_calculated_attributes

  enum status: Bike::STATUS_ENUM

  class << self
    def find_or_search_registry_for(serial_number:)
      serial_normalized = SerialNormalizer.new(serial: serial_number).normalized

      matches = ExternalRegistryBike.where(serial_normalized: serial_normalized)
      return matches if matches.any?

      matches = ExternalRegistryClient.search_for_bikes_with(serial_number)

      exact_matches = matches.where(serial_normalized: serial_normalized)
      return exact_matches if exact_matches.any?

      matches
    end

    # These are the currently known statuses
    def status_converter(status)
      case status.downcase
      when "stolen" then "status_stolen"
      when "abandoned" then "status_abandoned"
      when "transferred", "registered", "pending transfer" then "status_with_owner"
      else # There is a new status! Fail, we need to figure out what to do with it
        raise "Uknown external registry status: #{status}"
      end
    end

    private

    def brand(brand_name)
      return "unknown_brand" if absent?(brand_name)
      brand_name
    end

    def colors(frame_color)
      return "unknown" if absent?(frame_color)
      frame_color
    end

    def absent?(value)
      value.presence.blank? || /geen|onbekend/i.match?(value)
    end
  end

  def frame_colors
    self[:frame_colors]&.split(/\s*,\s*/) || []
  end

  # Statuses that come in are: transferred, abandoned, registered, pending transfer, stolen
  # TODO: make them align with the bike statuses
  def status_stolen?
    status&.downcase.match?("stolen")
  end

  def title_string
    "#{mnfg_name} #{frame_model}"
  end

  def registry_name
    raise NotImplementedError
  end

  def registry_url
    raise NotImplementedError
  end

  def image_url
  end

  def thumb_url
  end

  def url
  end

  private

  def set_calculated_attributes
    self.status ||= "status_with_owner"
    self.serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
  end
end
