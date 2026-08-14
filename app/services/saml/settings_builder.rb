# Builds the ruby-saml Settings for an organization's SAML configuration.
# Used both to generate SP metadata and to drive SP-initiated login.
# The SP keypair is shared app-wide via ENV; only the IdP details are per-organization.
module Saml
  module SettingsBuilder
    extend Functionable

    HTTP_POST = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"

    def build(saml_configuration)
      settings = OneLogin::RubySaml::Settings.new
      assign_sp(settings, saml_configuration)
      assign_idp(settings, saml_configuration)
      assign_security(settings)
      settings
    end

    def sp_entity_id(saml_configuration)
      "#{base_url}/sso/#{slug(saml_configuration)}/metadata"
    end

    def assertion_consumer_service_url(saml_configuration)
      "#{base_url}/sso/#{slug(saml_configuration)}/callback"
    end

    #
    # private below here
    #
    def sp_certificate
      ENV["SAML_SP_CERTIFICATE"].presence
    end

    def sp_private_key
      ENV["SAML_SP_PRIVATE_KEY"].presence
    end

    def slug(saml_configuration)
      saml_configuration.organization.to_param
    end

    def base_url
      ENV["BASE_URL"]
    end

    def assign_sp(settings, saml_configuration)
      settings.sp_entity_id = sp_entity_id(saml_configuration)
      settings.assertion_consumer_service_url = assertion_consumer_service_url(saml_configuration)
      settings.assertion_consumer_service_binding = HTTP_POST
      settings.certificate = sp_certificate
      settings.private_key = sp_private_key
    end

    def assign_idp(settings, saml_configuration)
      settings.idp_entity_id = saml_configuration.idp_entity_id
      settings.idp_sso_service_url = saml_configuration.idp_sso_target_url
      settings.idp_slo_service_url = saml_configuration.idp_slo_target_url
      settings.name_identifier_format = saml_configuration.name_id_format.presence

      certs = saml_configuration.idp_certificates
      if certs.many?
        settings.idp_cert_multi = {signing: certs, encryption: []}
      else
        settings.idp_cert = certs.first
      end
    end

    def assign_security(settings)
      settings.soft = true # collect validation errors instead of raising
      settings.security[:want_assertions_signed] = true
      settings.security[:authn_requests_signed] = true
      # Metadata-only in ruby-saml: adds the encryption KeyDescriptor so an IdP that encrypts
      # has a key to encrypt to. It requires nothing — decryption runs off the SP private key
      # whenever an EncryptedAssertion arrives, set or not.
      settings.security[:want_assertions_encrypted] = true
      settings.security[:digest_method] = XMLSecurity::Document::SHA256
      settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA256
    end

    conceal :sp_certificate, :sp_private_key, :slug,
      :base_url, :assign_sp, :assign_idp, :assign_security
  end
end
