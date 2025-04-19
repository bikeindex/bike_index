# frozen_string_literal: true

module AddressRecorded
  extend ActiveSupport::Concern

  included do
    belongs_to :address_record
    accepts_nested_attributes_for :address_record

    delegate :address_present?, :address_hash, :formatted_address_string,
      to: :address_record, allow_nil: true
  end

  def to_coordinates
    [latitude, longitude]
  end

  def address_hash_legacy
    return address_record.address_hash_legacy if address_record.present?
    # To ease migration, use the existing attrs. Handle if they've been dropped
    return {} unless defined?(street)

    # Copies Geocodeable#address_hash
    address_attrs = Geocodeable.location_attrs - %w[country_id country state_id state neighborhood]
    attributes.slice(*address_attrs)
      .merge(state: legacy_state_abbr, country: legacy_country_iso)
      .to_a.map { |k, v| [k, v.blank? ? nil : v] }.to_h # Return blank attrs as nil
      .with_indifferent_access
  end

  private

  def legacy_state_abbr
    return nil unless state_id.present?

    State.find(state_id)&.abbreviation
  end

  def legacy_country_iso
    return nil unless country_id.present?

    Country.find(country_id)&.iso
  end
end
