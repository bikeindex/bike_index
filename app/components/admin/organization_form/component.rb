# frozen_string_literal: true

module Admin
  module OrganizationForm
    class Component < ApplicationComponent
      DOMAIN_FEATURES = {
        "passwordless_users" => "passwordless sign in",
        "saml_sso" => "SAML SSO",
        "user_role_for_user_email_domain" => "automatic user role"
      }.freeze

      def initialize(form_builder:, organization:, current_user:, embedable_email: nil)
        @form_builder = form_builder
        @organization = organization
        @current_user = current_user
        @embedable_email = embedable_email
      end

      private

      def kind_options
        Organization.kinds.map { |kind| [Organization.kind_humanized(kind), kind] }
      end

      def parent_organization_options
        Organization.with_enabled_feature_slugs("child_organizations").pluck(:name, :id)
      end

      def auto_user_emails
        emails = @organization.users.pluck(:email)
        emails.any? ? emails : [ENV["AUTO_ORG_MEMBER"]]
      end

      def domain_uses
        DOMAIN_FEATURES.filter_map { |slug, name| name if @organization.enabled?(slug) }
      end

      def stolen_message_kind_options
        [["Association: Evey associated stolen bike sees message. Default for schools", "association"],
          ["Area: seen by bikes stolen in radius. Default for law enforcement, advocacy", "area"]]
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

      def manual_pos_kind_entries
        [{value: "not_set", label: "not set"}] +
          Organization.pos_kinds.map { |pos_kind| {value: pos_kind, label: pos_kind.humanize.gsub("pos", "").strip} }
      end

      def selected_manual_pos_kind
        @organization.manual_pos_kind.presence || "not_set"
      end

      def organization_stolen_message
        @organization_stolen_message ||= OrganizationStolenMessage.for(@organization)
      end

      def saml_configuration
        @saml_configuration ||= @organization.organization_saml_configuration ||
          @organization.build_organization_saml_configuration
      end
    end
  end
end
