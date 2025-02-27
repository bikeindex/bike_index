# == Schema Information
#
# Table name: external_registry_bikes
#
#  id                        :integer          not null, primary key
#  category                  :string
#  cycle_type                :string
#  date_stolen               :datetime
#  description               :string
#  external_updated_at       :datetime
#  extra_registration_number :string
#  frame_colors              :string
#  frame_model               :string
#  info_hash                 :jsonb
#  location_found            :string
#  mnfg_name                 :string
#  serial_normalized         :string           not null
#  serial_number             :string           not null
#  status                    :integer
#  type                      :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  country_id                :integer          not null
#  external_id               :string           not null
#
# Indexes
#
#  index_external_registry_bikes_on_country_id         (country_id)
#  index_external_registry_bikes_on_external_id        (external_id)
#  index_external_registry_bikes_on_serial_normalized  (serial_normalized)
#  index_external_registry_bikes_on_type               (type)
#
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

  enum :status, Bike::STATUS_ENUM

  class << self
    def registry_name(str)
      return nil unless str.present?
      reg = str.to_s.split("::").last.gsub("Bike", "")
      return "StopHeling.nl" if reg == "StopHeling"
      return "VerlorenOfGevonden.nl" if reg == "VerlorenOfGevonden"
      reg.titleize
    end

    def find_or_search_registry_for(serial_number:)
      serial_normalized = SerialNormalizer.normalized_and_corrected(serial_number)

      matches = ExternalRegistryBike.where(serial_normalized: serial_normalized)
      return matches if matches.any?

      matches = ExternalRegistryClient.search_for_bikes_with(serial_number)

      exact_matches = matches.where(serial_normalized: serial_normalized)
      return exact_matches if exact_matches.any?

      matches
    end

    def impounded_kind
      ImpoundRecord.found_kind
    end

    # These are the currently known statuses
    def status_converter(status)
      case status.downcase
      when "stolen" then "status_stolen"
      when "abandoned" then "status_impounded"
      when "new", "transferred", "registered", "pending transfer", "recovered", "for_sale" then "status_with_owner"
      else # There is a new status! Fail, we need to figure out what to do with it
        raise "Unknown external registry status: #{status}"
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

  def short_address
    return nil unless location_found.present?
    addy = location_found.split(",")
    shorter_length = (addy.length > 3) ? 3 : addy.length
    addy[-shorter_length..].reject(&:blank?).map(&:strip).join(", ")
  end

  def status_humanized
    shuman = Bike.status_humanized(status)
    return self.class.impounded_kind if shuman == "impounded"
    shuman
  end

  def status_humanized_translated
    Bike.status_humanized_translated(status_humanized)
  end

  def propulsion_type
    "foot-pedal"
  end

  def cycle_type
    "bike"
  end

  def frame_colors
    self[:frame_colors]&.split(/\s*,\s*/) || []
  end

  def title_string
    "#{mnfg_name} #{frame_model}"
  end

  def registry_name
    self.class.registry_name(type)
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
    self.serial_normalized = SerialNormalizer.normalized_and_corrected(serial_number)
  end
end
