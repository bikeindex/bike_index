# frozen_string_literal: true

module LegacyFormWell::AddressRecord
  class Component < ApplicationComponent
    STATIC_FIELDS_OPTIONS = %i[shown hidden]

    def initialize(form_builder:, organization: nil, no_street: false, not_related_fields: false, static_fields: false)

      @builder = form_builder
      @no_street = no_street
      @organization = organization
      @initial_country_id = form_builder.object.country_id
      @wrapper_class = not_related_fields ? "" : "related-fields"
      @static_fields = STATIC_FIELDS_OPTIONS.include?(static_fields) ? static_fields : false
    end

    private

    def non_static_field_class
      return "" unless @static_fields

      @static_fields == :shown ? "tw:hidden!" : ""
    end

    def static_field_class
      return "" unless @static_fields

      @static_fields == :hidden ? "tw:hidden!" : ""
    end

    def no_street?
      @no_street
    end

    def initial_state_class
      (@initial_country_id == Country.united_states_id) ? "" : "tw:hidden!" # Should check if address_object.country_id == Country.united_states_id
    end

    def initial_region_class
      initial_state_class.blank? ? "tw:hidden!" : ""
    end

    def address_label
      txt = @organization&.registration_field_labels&.dig("reg_address")
      return txt.html_safe if txt.present?

      no_street? ? translation(:address_no_street) : translation(:address)
    end

    def street_placeholder
      translation(@organization&.school? ? :address_school : :address)
    end

    def street_requires_below_helper?
      @organization&.additional_registration_fields&.include?("reg_address") || false
    end
  end
end
