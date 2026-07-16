# Validates a SAMLResponse and resolves it to a Bike Index user.
# ruby-saml's #is_valid? does the security-critical work (signature, conditions,
# audience, recipient/destination, and InResponseTo when matches_request_id is given);
# we layer on email extraction and the SsoIdentity link/provision policy.
module Saml
  class AssertionProcessor
    Result = Struct.new(:user, :error) do
      def success?
        error.nil?
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(saml_configuration:, raw_response:, request_id:)
      @saml_configuration = saml_configuration
      @raw_response = raw_response
      @request_id = request_id
    end

    def call
      return failure("missing SAML response") if @raw_response.blank?

      response = parse_response
      return failure(response.errors.join("; ").presence || "invalid SAML response") unless response.is_valid?

      name_id = response.name_id.presence
      return failure("assertion is missing a NameID") if name_id.blank?

      email = asserted_email(response)
      return failure("assertion is missing an email") if email.blank?

      # One lookup drives both the returning-user short-circuit and the post-login update.
      identity = SsoIdentity.for(organization:, provider:, uid: name_id) ||
        SsoIdentity.new(organization:, provider:, uid: name_id)
      user = identity.user || User.fuzzy_confirmed_or_unconfirmed_email_find(email) || provision_user(email)
      return failure("no Bike Index account for #{email}") if user.blank?

      identity.update(user:, email:, name_id_format: response.name_id_format, last_sign_in_at: Time.current)
      Result.new(user:)
    rescue OneLogin::RubySaml::ValidationError => e
      failure(e.message)
    end

    private

    def organization
      @saml_configuration.organization
    end

    def provider
      OrganizationSamlConfiguration::PROVIDER
    end

    def parse_response
      settings = Saml::SettingsBuilder.build(@saml_configuration)
      OneLogin::RubySaml::Response.new(@raw_response,
        settings:, matches_request_id: @request_id, allowed_clock_drift: 30.seconds)
    end

    def asserted_email(response)
      raw = response.attributes[@saml_configuration.email_attribute].presence || response.name_id
      EmailNormalizer.normalize(raw)
    end

    # Only mint an account when the email's domain belongs to this org, so an assertion
    # can never create a cross-domain account.
    def provision_user(email)
      return nil unless Organization.passwordless_email_matching(email)&.id == organization.id

      OrganizationRole.create_passwordless(invited_email: email,
        organization_id: organization.id, created_by_magic_link: true).user
    end

    def failure(message)
      Result.new(error: message)
    end
  end
end
