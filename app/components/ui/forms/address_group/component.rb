# frozen_string_literal: true

module UI
  module Forms
    module AddressGroup
      # Street/city/region/postal/country fields with a Stimulus-driven US-state
      # vs free-text-region toggle. The form object must expose the geocodeable
      # address attributes (street, city, region_record_id, region_string,
      # postal_code, country_id)
      class Component < ApplicationComponent
        def initialize(form_builder:, street_label: nil, default_country_id: Country.united_states_id)
          @form = form_builder
          @street_label = street_label
          @default_country_id = default_country_id
        end

        private

        def street_label
          @street_label || translation(".address")
        end

        def us_country_id
          Country.united_states_id
        end

        # The object's country, falling back to the default, so the dropdown and the
        # state/region visibility agree on load
        def selected_country_id
          @form.object.country_id || @default_country_id
        end

        # US shows the state select; other countries the free-text region field
        def state_hidden_class
          "tw:hidden" unless us_selected?
        end

        def region_hidden_class
          "tw:hidden" if us_selected?
        end

        def us_selected?
          selected_country_id == us_country_id
        end
      end
    end
  end
end
