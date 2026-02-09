# frozen_string_literal: true

module Org::LocationAddressFields
  class Component < ApplicationComponent
    def initialize(form_builder:)
      @builder = form_builder

      @initial_country_id = @builder.object.country_id || Country.united_states_id
    end

    private

    def initial_state_class
      (@initial_country_id == Country.united_states_id) ? "" : "tw:hidden!"
    end

    def initial_region_class
      initial_state_class.blank? ? "tw:hidden!" : ""
    end
  end
end
