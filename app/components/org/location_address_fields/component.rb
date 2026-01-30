# frozen_string_literal: true

module Org::LocationAddressFields
  class Component < ApplicationComponent
    def initialize(form_builder:, default_country_id: nil, default_region_record_id: nil, default_region_string: nil)
      @builder = form_builder

      @builder.object.country_id ||= default_country_id || Country.united_states_id
      @initial_country_id = @builder.object.country_id

      @builder.object.region_record_id ||= default_region_record_id
      @initial_region_record_id = @builder.object.region_record_id

      @default_region_string = default_region_string # TODO: Make this actually do something
    end

    private

    def initial_state_class
      (@initial_country_id == Country.united_states_id) ? "" : "tw:hidden!" # Should check if address_object.country_id == Country.united_states_id
    end

    def initial_region_class
      initial_state_class.blank? ? "tw:hidden!" : ""
    end
  end
end
