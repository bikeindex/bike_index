# Validates a SAMLResponse and resolves it to a Bike Index user.
# ruby-saml's #is_valid? does the security-critical work (signature, conditions,
# audience, recipient/destination, and InResponseTo when matches_request_id is given);
# we layer on email extraction and the SsoIdentity link/provision policy.
module Saml
  module AssertionProcessor
    extend Functionable

    Result = Struct.new(:user, :error) do
      def success?
        error.nil?
      end
    end

    def call(saml_configuration:, raw_response:, request_id:)
      return failure("missing SAML response") if raw_response.blank?

      response = parse_response(saml_configuration, raw_response, request_id)
      return failure(response.errors.join("; ").presence || "invalid SAML response") unless response.is_valid?

      name_id = response.name_id.presence
      return failure("assertion is missing a NameID") if name_id.blank?

      email = asserted_email(response, saml_configuration)
      return failure("assertion is missing an email") if email.blank?

      organization = saml_configuration.organization
      # One lookup drives both the returning-user short-circuit and the post-login update.
      identity = SsoIdentity.for(organization:, provider:, uid: name_id) ||
        SsoIdentity.new(organization:, provider:, uid: name_id)
      user = identity.user || User.fuzzy_confirmed_or_unconfirmed_email_find(email) || provision_user(email, organization)
      return failure("no Bike Index account for #{email}") if user.blank?

      # The IdP vouched for this email, so confirm the account (as the magic-link path
      # does) — otherwise sign-in bounces an unconfirmed user to the confirm-email page.
      user.confirm(user.confirmation_token) unless user.confirmed?

      identity.update(user:, email:, name_id_format: response.name_id_format, last_sign_in_at: Time.current)
      Result.new(user:)
    rescue OneLogin::RubySaml::ValidationError => e
      failure(e.message)
    end

    def provider
      OrganizationSamlConfiguration::PROVIDER
    end

    def parse_response(saml_configuration, raw_response, request_id)
      settings = Saml::SettingsBuilder.build(saml_configuration)
      OneLogin::RubySaml::Response.new(raw_response,
        settings:, matches_request_id: request_id, allowed_clock_drift: 30.seconds)
    end

    def asserted_email(response, saml_configuration)
      raw = response.attributes[saml_configuration.email_attribute].presence || response.name_id
      EmailNormalizer.normalize(raw)
    end

    # Only mint an account when the email's domain belongs to this org, so an assertion
    # can never create a cross-domain account.
    def provision_user(email, organization)
      return nil unless Organization.passwordless_email_matching(email)&.id == organization.id

      OrganizationRole.create_passwordless(invited_email: email,
        organization_id: organization.id, created_by_magic_link: true).user
    end

    def failure(message)
      Result.new(error: message)
    end

    conceal :provider, :parse_response, :asserted_email, :provision_user, :failure
  end
end
