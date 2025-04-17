# frozen_string_literal: true

module LegacyFormWell::AddressRecord
  class Component < ApplicationComponent
    US_ID = Country.united_states_id

    def initialize(form_builder:,  organization: nil, no_street: false)
      @builder = form_builder
      @no_street = no_street
      @organization = organization
      @initial_country_id = form_builder.object.country_id
    end

    private

    def no_street?
      @no_street
    end

    def initial_state_class
      @initial_country_id == US_ID ? "" : "tw:hidden!" # Should check if address_object.country_id == Country.united_states_id
    end

    def initial_region_class
      initial_state_class.blank? ? "tw:hidden!" : ""
    end

    def address_label
      txt = @organization&.registration_field_labels&.dig("reg_address")

      txt.present? ? txt.html_safe : translation(:address)
    end

    def street_placeholder
      translation(@organization&.school? ? :address_school : :address)
    end

    def street_requires_below_helper?
      @organization&.additional_registration_fields&.include?("reg_address") || false
    end

    def builder
      @builder
    end
  end
end
