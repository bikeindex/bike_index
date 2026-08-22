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

    DiagnosticResult = Struct.new(:name_id, :name_id_format, :attributes,
      :email_attribute, :email, :email_domain, :user, :user_has_password, :error) do
      def success?
        error.nil?
      end
    end

    def call(saml_configuration:, raw_response:, request_id:, dry_run: false)
      return failure("missing SAML response") if raw_response.blank?

      response = parse_response(saml_configuration, raw_response, request_id)
      return failure(response.errors.join("; ").presence || "invalid SAML response") unless response.is_valid?

      organization = saml_configuration.organization
      name_id = response.name_id.presence
      email = asserted_email(response, saml_configuration)
      error = resolution_error(name_id:, email:, organization:)
      return diagnostic(response, saml_configuration, name_id:, email:, error:) if dry_run
      return failure(error) if error

      # One lookup drives both the returning-user short-circuit and the post-login update.
      identity = SsoIdentity.for(organization:, provider:, uid: name_id) ||
        SsoIdentity.new(organization:, provider:, uid: name_id)
      user = identity.user || User.fuzzy_confirmed_or_unconfirmed_email_find(email) || provision_user(email)
      return failure("no Bike Index account for #{email}") if user.blank?

      # The IdP vouched for this email, so confirm the account (as the magic-link path
      # does) — otherwise sign-in bounces an unconfirmed user to the confirm-email page.
      user.confirm(user.confirmation_token) unless user.confirmed?

      identity.update(user:, email:, name_id_format: response.name_id_format, last_sign_in_at: Time.current)
      Result.new(user:)
    rescue OneLogin::RubySaml::ValidationError => e
      failure(e.message)
    end

    #
    # private below here
    #
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

    def resolution_error(name_id:, email:, organization:)
      return "assertion is missing a NameID" if name_id.blank?
      return "assertion is missing an email" if email.blank?

      # Guards the whole resolution, not just provisioning: otherwise an assertion for any address -
      # another org's admin, a superadmin - links or returns an existing account and signs it in.
      asserted_domain = Organization.email_domain(email)
      "#{email} is not on this organization's SSO domain" unless
        asserted_domain.present? && asserted_domain == organization.user_email_domain
    end

    def diagnostic(response, saml_configuration, name_id:, email:, error:)
      email_domain = Organization.email_domain(email)
      # Looked up only once the domain guard clears it, as the live path does
      user = User.fuzzy_confirmed_or_unconfirmed_email_find(email) if
        email_domain.present? && email_domain == saml_configuration.organization.user_email_domain

      DiagnosticResult.new(
        name_id:, name_id_format: response.name_id_format,
        attributes: response.attributes.all,
        email_attribute: saml_configuration.email_attribute,
        email:, email_domain:, user:,
        user_has_password: user.present? && !user.passwordless_user?, error:
      )
    end

    # Provisioning grants no organization role - that is user_role_for_user_email_domain's job.
    def provision_user(email)
      UserServices::PasswordlessCreator.find_or_create(email).first
    end

    def failure(message)
      Result.new(error: message)
    end

    conceal :provider, :parse_response, :asserted_email, :resolution_error, :diagnostic,
      :provision_user, :failure
  end
end
