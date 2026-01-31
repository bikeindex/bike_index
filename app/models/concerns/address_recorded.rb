# frozen_string_literal: true

module AddressRecorded
  extend ActiveSupport::Concern

  included do
    belongs_to :address_record, autosave: true
    accepts_nested_attributes_for :address_record

    delegate :address_present?, :address_hash, :formatted_address_string,
      to: :address_record, allow_nil: true

    scope :address_record, -> { where.not(address_record_id: nil) }
    scope :with_street, -> { includes(:address_record).where.not(address_records: {street: nil}) }
    scope :without_street, -> { includes(:address_record).where(address_records: {street: nil}) }
  end

  def address_hash_legacy(address_record_id: false)
    return address_record.address_hash_legacy(address_record_id:) if address_record?
    # To ease migration, use the existing attrs. Handle if they've been dropped
    return {} unless has_attribute?(:street)

    # Copies Geocodeable#address_hash
    address_attrs = Geocodeable.location_attrs - %w[country_id country state_id state neighborhood]
    attributes.slice(*address_attrs)
      .merge(state: legacy_state_abbr, country: legacy_country_iso)
      .to_a.map { |k, v| [k, v.blank? ? nil : v] }.to_h # Return blank attrs as nil
      .with_indifferent_access
  end

  def address_record?
    address_record.present?
  end

  private

  def legacy_state_abbr
    return nil unless has_attribute?(:state_id) && state_id.present?

    State.find(state_id)&.abbreviation
  end

  def legacy_country_iso
    return nil unless has_attribute?(:country_id) && country_id.present?

    Country.find(country_id)&.iso
  end
end
