# Validates a SAMLResponse and resolves it to a Bike Index user.
# ruby-saml's #is_valid? does the security-critical work (signature, conditions,
# audience, recipient/destination, and InResponseTo when matches_request_id is given);
# we layer on email extraction and the SsoIdentity link/provision policy.
module Saml
  class AssertionProcessor
    # name_id/name_id_format/session_index are carried through so the controller can
    # remember them for a later Single Logout request.
    Result = Struct.new(:user, :name_id, :name_id_format, :session_index, :error) do
      def success?
        error.nil?
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(saml_configuration:, raw_response:, request_id:, idp_initiated: false)
      @saml_configuration = saml_configuration
      @raw_response = raw_response
      @request_id = request_id
      @idp_initiated = idp_initiated
    end

    def call
      return failure("missing SAML response") if @raw_response.blank?

      response = parse_response
      return failure(response.errors.join("; ").presence || "invalid SAML response") unless response.is_valid?

      # IdP-initiated logins carry no InResponseTo to replay-check against, so we enforce
      # one-time use of the assertion id instead.
      return failure("assertion has already been used") if @idp_initiated && !claim_assertion(response)

      name_id = response.name_id.presence
      return failure("assertion is missing a NameID") if name_id.blank?

      email = asserted_email(response)
      return failure("assertion is missing an email") if email.blank?

      user = find_or_provision_user(email:, name_id:)
      return failure("no Bike Index account for #{email}") if user.blank?

      record_identity(user:, name_id:, email:, name_id_format: response.name_id_format)
      Result.new(user:, name_id:, name_id_format: response.name_id_format, session_index: response.sessionindex)
    rescue OneLogin::RubySaml::ValidationError => e
      failure(e.message)
    end

    private

    # Returns false when this assertion id has already been seen (within the validity window).
    def claim_assertion(response)
      assertion_id = response.assertion_id.presence
      return false if assertion_id.blank?

      Rails.cache.write("saml/idp_initiated/#{assertion_id}", true, unless_exist: true, expires_in: 12.hours)
    end

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

    def find_or_provision_user(email:, name_id:)
      existing_identity = SsoIdentity.for(organization:, provider:, uid: name_id)
      return existing_identity.user if existing_identity

      User.fuzzy_confirmed_or_unconfirmed_email_find(email) || provision_user(email)
    end

    # Only mint an account when the email's domain belongs to this org, so an assertion
    # can never create a cross-domain account.
    def provision_user(email)
      return nil unless Organization.passwordless_email_matching(email)&.id == organization.id

      OrganizationRole.create_passwordless(invited_email: email,
        organization_id: organization.id, created_by_magic_link: true).user
    end

    def record_identity(user:, name_id:, email:, name_id_format:)
      identity = SsoIdentity.for(organization:, provider:, uid: name_id) ||
        SsoIdentity.new(organization:, provider:, uid: name_id)
      identity.update(user:, email:, name_id_format:, last_sign_in_at: Time.current)
    end

    def failure(message)
      Result.new(error: message)
    end
  end
end
