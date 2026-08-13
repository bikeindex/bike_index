# frozen_string_literal: true

module Admin
  module OrganizationFeatureSettings
    # The settings an organization's enabled features add to the admin organization form
    class Component < ApplicationComponent
      DOMAIN_FEATURES = {
        "passwordless_users" => "passwordless sign in",
        "saml_sso" => "SAML SSO",
        "user_role_for_user_email_domain" => "automatic user role"
      }.freeze

      def self.any_for?(organization)
        organization.any_enabled?(OrganizationFeature.with_admin_organization_attributes)
      end

      def initialize(form_builder:, organization:, current_user:)
        @form_builder = form_builder
        @organization = organization
        @current_user = current_user
      end

      private

      def domain_uses
        @domain_uses ||= DOMAIN_FEATURES.filter_map { |slug, name| name if @organization.enabled?(slug) }
      end

      def search_radius_attribute
        @organization.search_radius_metric_units? ? :search_radius_kilometers : :search_radius_miles
      end

      def stolen_message_kind_options
        [["Association: Evey associated stolen bike sees message. Default for schools", "association"],
          ["Area: seen by bikes stolen in radius. Default for law enforcement, advocacy", "area"]]
      end

      def organization_stolen_message
        @organization_stolen_message ||= OrganizationStolenMessage.for(@organization)
      end

      # A top-level param rather than an organization attribute
      def stolen_message_radius_attribute
        if organization_stolen_message.search_radius_metric_units?
          :organization_stolen_message_search_radius_kilometers
        else
          :organization_stolen_message_search_radius_miles
        end
      end

      def stolen_message_radius_value
        if organization_stolen_message.search_radius_metric_units?
          organization_stolen_message.search_radius_kilometers
        else
          organization_stolen_message.search_radius_miles
        end
      end

      def saml_configuration
        @saml_configuration ||= @organization.organization_saml_configuration ||
          @organization.build_organization_saml_configuration
      end
    end
  end
end
