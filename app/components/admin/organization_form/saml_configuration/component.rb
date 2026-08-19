# frozen_string_literal: true

module Admin
  module OrganizationForm
    module SamlConfiguration
      class Component < ApplicationComponent
        def initialize(form_builder:, current_user:)
          @form_builder = form_builder
          @organization = form_builder.object
          @current_user = current_user
        end

        def render? = @organization.enabled?("saml_sso")

        private

        # The IdP details decide which identity provider an email domain is handed to, and
        # which signing key its assertions are trusted against - the same reasoning that
        # keeps user_email_domain developer-only
        def developer? = @current_user.developer?

        def saml_configuration
          @saml_configuration ||= @organization.organization_saml_configuration ||
            @organization.build_organization_saml_configuration
        end

        def metadata_url = saml_metadata_url(org_slug: @organization.to_param, format: :xml)

        def field_options = {disabled: !developer?}
      end
    end
  end
end
