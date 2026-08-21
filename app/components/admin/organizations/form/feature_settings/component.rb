# frozen_string_literal: true

module Admin
  module Organizations
    module Form
      module FeatureSettings
        class Component < ApplicationComponent
          DOMAIN_FEATURES = {
            "passwordless_users" => "passwordless sign in",
            "saml_sso" => "SAML SSO",
            "user_role_for_user_email_domain" => "automatic user role"
          }.freeze

          def initialize(form_builder:, current_user:)
            @form_builder = form_builder
            @organization = form_builder.object
            @current_user = current_user
          end

          private

          def developer? = @current_user.developer?

          def domain_uses
            @domain_uses ||= DOMAIN_FEATURES.filter_map { |slug, name| name if @organization.enabled?(slug) }
          end

          def search_radius
            @search_radius ||= if @organization.search_radius_metric_units?
              {attribute: :search_radius_kilometers, unit: "km"}
            else
              {attribute: :search_radius_miles, unit: "mi"}
            end
          end

          # The email fields aren't features, so paid? is what gates them
          def customizable_reg_fields
            @customizable_reg_fields ||= OrganizationFeature.reg_fields_with_customizable_labels.select do |reg_field|
              if OrganizationFeature.email_customizable_labels.include?(reg_field)
                @organization.paid?
              else
                @organization.enabled?(reg_field)
              end
            end
          end

          def reg_field_text(reg_field)
            case reg_field
            when "owner_email"
              {label: safe_join(["Custom Label for ", tag.em("Owner Email"), ' (e.g. "uiowa.edu email")']),
               note: "often desired by universities"}
            when "email_placeholder"
              {label: safe_join(["Custom Placeholder for ", tag.em("Owner Email"), ' (e.g. "you@uiowa.edu")']),
               note: "the greyed out example inside the empty field"}
            else
              {label: safe_join(["Custom Label for ",
                tag.em(OrganizationFeature.reg_field_to_bike_attrs(reg_field).titleize(keep_id_suffix: true))]),
               note: safe_join(["leave blank unless it's ", tag.strong("absolutely"),
                 " required - default behavior is preferred"])}
            end
          end

          def stolen_message_kind_options
            [["Association: Evey associated stolen bike sees message. Default for schools", "association"],
              ["Area: seen by bikes stolen in radius. Default for law enforcement, advocacy", "area"]]
          end

          def organization_stolen_message
            @organization_stolen_message ||= OrganizationStolenMessage.for(@organization)
          end

          # attribute is a top-level param rather than an organization attribute
          def stolen_message_radius
            @stolen_message_radius ||= if organization_stolen_message.search_radius_metric_units?
              {attribute: :organization_stolen_message_search_radius_kilometers, unit: "km",
               value: organization_stolen_message.search_radius_kilometers,
               max: "#{OrganizationStolenMessage.max_search_radius_kilometers} km"}
            else
              {attribute: :organization_stolen_message_search_radius_miles, unit: "mi",
               value: organization_stolen_message.search_radius_miles,
               max: "#{OrganizationStolenMessage::MAX_SEARCH_RADIUS} miles"}
            end
          end
        end
      end
    end
  end
end
