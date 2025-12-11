# frozen_string_literal: true

module LegacyFormWell::AddressRecord
  class Component < ApplicationComponent
    STATIC_FIELDS_OPTIONS = %i[shown hidden]

    # NOTE: Keep in mind this renders for the embed and embed_extended views (which don't have tailwind styles)
    def initialize(form_builder:, organization: nil, not_related_fields: false,
      static_fields: false, current_country_id: nil, embed_layout: false, no_street: nil, street_2: false)
      @builder = form_builder
      @organization = organization

      @no_street = no_street?(no_street, @builder.object, @organization)
      @street_2 = !no_street && street_2

      @builder.object.country_id ||= current_country_id
      @initial_country_id = @builder.object.country_id
      @static_fields = STATIC_FIELDS_OPTIONS.include?(static_fields) ? static_fields : false
      @embed_layout = BinxUtils::InputNormalizer.boolean(embed_layout)

      @wrapper_class = if @embed_layout
        "input-group"
      else
        not_related_fields ? "" : "related-fields"
      end
    end

    private

    def no_street?(no_street, object, organization)
      # If it's not nil, assume it was passed deliberately
      return no_street if [true, false].include?(no_street)

      object.user.present? && object.user.no_address ||
        organization.present? && organization&.enabled?("no_address")
    end

    def country_required?
      @builder.object.address_present?
    end

    def non_static_field_class
      return "" unless @static_fields

      (@static_fields == :shown) ? "tw:hidden!" : ""
    end

    def static_field_class
      return "" unless @static_fields

      (@static_fields == :hidden) ? "tw:hidden!" : ""
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

      @no_street ? translation(:address_no_street) : translation(:address)
    end

    def street_placeholder
      translation(@organization&.school? ? :address_school : :address)
    end

    def address_required?
      @organization&.enabled?("require_reg_address")
    end
  end
end
