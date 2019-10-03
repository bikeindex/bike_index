class ExternalRegistryBike < ActiveRecord::Base
  belongs_to :country, class_name: "Country"

  validates \
    :country,
    :external_id,
    :serial_number,
    presence: true

  validates :external_id, uniqueness: { scope: :type }

  before_save :normalize_serial_number

  class << self
    def find_or_search_registry_for(serial_number:)
      matches = ExternalRegistryBike.where(serial_number: serial_number)
      return matches if matches.any?

      matches = ExternalRegistry::ExternalRegistry.search_for_bikes_with(
        serial_number: serial_number,
      )

      exact_matches = matches.where(serial_number: serial_number)
      return exact_matches if exact_matches.any?

      matches
    end

    private

    def brand(brand_name)
      return "Unknown Brand" if absent?(brand_name)
      brand_name
    end

    def colors(frame_color)
      return "Unknown" if absent?(frame_color)
      frame_color
    end

    def absent?(value)
      value.presence.blank? || value.match?(/geen|onbekend/i)
    end
  end

  def stolen?
    status&.downcase == "stolen"
  end

  def title_string
    "#{mnfg_name} #{frame_model}"
  end

  def external_registry_name
    raise NotImplementedError
  end

  def external_registry_url
    raise NotImplementedError
  end

  def image_url; end
  def thumb_url; end
  def url; end

  private

  def normalize_serial_number
    self.serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
  end
end
