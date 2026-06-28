# Builds the ruby-saml Settings for an organization's SAML configuration.
# Used both to generate SP metadata (PR2) and to drive SP-initiated login (PR3).
# The SP keypair is shared app-wide via ENV; only the IdP details are per-organization.
module Saml
  class SettingsBuilder
    HTTP_POST = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
    HTTP_REDIRECT = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"

    def self.build(saml_configuration)
      new(saml_configuration).build
    end

    def self.sp_certificate
      ENV["SAML_SP_CERTIFICATE"].presence
    end

    def self.sp_private_key
      ENV["SAML_SP_PRIVATE_KEY"].presence
    end

    def initialize(saml_configuration)
      @saml_configuration = saml_configuration
    end

    def build
      settings = OneLogin::RubySaml::Settings.new
      assign_sp(settings)
      assign_idp(settings)
      assign_security(settings)
      settings
    end

    def slug
      @saml_configuration.organization.to_param
    end

    def sp_entity_id
      "#{base_url}/sso/#{slug}/metadata"
    end

    def assertion_consumer_service_url
      "#{base_url}/sso/#{slug}/callback"
    end

    def single_logout_service_url
      "#{base_url}/sso/#{slug}/slo"
    end

    private

    def base_url
      ENV["BASE_URL"]
    end

    def assign_sp(settings)
      settings.sp_entity_id = sp_entity_id
      settings.assertion_consumer_service_url = assertion_consumer_service_url
      settings.assertion_consumer_service_binding = HTTP_POST
      settings.single_logout_service_url = single_logout_service_url
      settings.single_logout_service_binding = HTTP_REDIRECT
      settings.certificate = self.class.sp_certificate
      settings.private_key = self.class.sp_private_key
    end

    def assign_idp(settings)
      settings.idp_entity_id = @saml_configuration.idp_entity_id
      settings.idp_sso_service_url = @saml_configuration.idp_sso_target_url
      settings.idp_slo_service_url = @saml_configuration.idp_slo_target_url
      settings.name_identifier_format = @saml_configuration.name_id_format.presence

      certs = @saml_configuration.idp_certificates
      if certs.many?
        settings.idp_cert_multi = {signing: certs, encryption: []}
      else
        settings.idp_cert = certs.first
      end
    end

    def assign_security(settings)
      settings.security[:want_assertions_signed] = true
      settings.security[:authn_requests_signed] = true
      settings.security[:digest_method] = XMLSecurity::Document::SHA256
      settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA256
    end
  end
end
