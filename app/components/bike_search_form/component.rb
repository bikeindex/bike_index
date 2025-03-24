# frozen_string_literal: true

module BikeSearchForm
  class Component < ApplicationComponent
    def initialize(include_organized_search_fields: false, serial: nil) #distance:, include_hidden_search_fields:, include_location_search:, location:, query:, raw_serial:, search_address:, search_email:, search_model_audit_id:, search_path:, search_secondary:, search_stickers:, serial:, skip_serial_field:, stolenness:)
      # @distance = distance
      # @include_hidden_search_fields = include_hidden_search_fields
      # @include_location_search = include_location_search
      # @include_organized_search_fields = include_organized_search_fields
      # @location = location
      # @query = query
      # @raw_serial = raw_serial
      # @search_address = search_address
      # @search_email = search_email
      # @search_model_audit_id = search_model_audit_id
      # @search_path = search_path
      # @search_secondary = search_secondary
      # @search_stickers = search_stickers
      @serial = serial
      # @skip_serial_field = skip_serial_field
      # @stolenness = stolenness
    end
  end
end
