# frozen_string_literal: true

module Admin
  module Organizations
    module Form
      module SamlSso
        class Component < ApplicationComponent
          def initialize(form_builder:)
            @form_builder = form_builder
            @organization = form_builder.object
          end

          private

          def saml_configuration
            @saml_configuration ||= @organization.organization_saml_configuration ||
              @organization.build_organization_saml_configuration
          end

          def metadata_url = saml_metadata_url(org_slug: @organization.to_param)

          def certificate_url = saml_certificate_url(org_slug: @organization.to_param)

          def test_url = saml_test_url(org_slug: @organization.to_param)
        end
      end
    end
  end
end
