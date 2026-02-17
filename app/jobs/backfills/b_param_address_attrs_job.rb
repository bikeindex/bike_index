# frozen_string_literal: true

class Backfills::BParamAddressAttrsJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority"

  # Legacy address keys that need to be converted to address_record_attributes
  LEGACY_ADDRESS_KEYS = %w[
    address address_street address_city address_state address_zipcode address_country
    street city state zipcode country
  ].freeze

  class << self
    def iterable_scope
      # Find BParams with legacy address keys in their bike params
      # Only look at records without created_bike_id (not yet processed)
      # or recent records that might still be used
      conditions = LEGACY_ADDRESS_KEYS.map { |key| "(params -> 'bike' -> '#{key}') IS NOT NULL" }
      BParam.where(conditions.join(" OR "))
    end

    def build_address_record_attributes(bike_params)
      return {} if bike_params.blank?

      ar_attrs = {}

      # street: address, address_street, or street
      ar_attrs["street"] = bike_params["street"] || bike_params["address"] || bike_params["address_street"]

      # city: city or address_city
      ar_attrs["city"] = bike_params["city"] || bike_params["address_city"]

      # postal_code: postal_code, zipcode, or address_zipcode
      ar_attrs["postal_code"] = bike_params["postal_code"] || bike_params["zipcode"] || bike_params["address_zipcode"]

      # region_string: region_string, state, or address_state
      ar_attrs["region_string"] = bike_params["region_string"] || bike_params["state"] || bike_params["address_state"]

      # country_id: country_id, country, or address_country
      ar_attrs["country_id"] = bike_params["country_id"] || bike_params["country"] || bike_params["address_country"]

      ar_attrs.compact!
      ar_attrs.presence
    end

    def cleaned_bike_params(bike_params)
      return bike_params if bike_params.blank?

      cleaned = bike_params.except(*LEGACY_ADDRESS_KEYS)
      address_attrs = build_address_record_attributes(bike_params)

      if address_attrs.present?
        cleaned["address_record_attributes"] = (bike_params["address_record_attributes"] || {}).merge(address_attrs)
      end

      cleaned
    end
  end

  def build_enumerator(cursor:)
    return if skip_job?

    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(b_param)
    bike_params = b_param.params&.dig("bike")
    return if bike_params.blank?

    cleaned = self.class.cleaned_bike_params(bike_params)
    return if cleaned == bike_params

    updated_params = b_param.params.merge("bike" => cleaned)
    b_param.update_column(:params, updated_params)
  end
end
