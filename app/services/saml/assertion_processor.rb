# Validates a SAMLResponse and resolves it to a Bike Index user.
# ruby-saml's #is_valid? does the security-critical work (signature, conditions,
# audience, recipient/destination, and InResponseTo when matches_request_id is given);
# we layer on email extraction and the SsoIdentity link/provision policy.
module Saml
  module AssertionProcessor
    extend Functionable

    # The asserted fields are carried whether or not resolution succeeded, so the test page
    # can tell an attribute-release problem from a domain mismatch. They are set only once
    # the signature validated, so their absence means there is no assertion to report.
    Result = Struct.new(:user, :error, :signed_up, :name_id, :name_id_format, :attributes,
      :email_attribute, :email, :email_domain) do
      def success?
        error.nil?
      end
    end

    def call(saml_configuration:, raw_response:, request_id:)
      return failure("missing SAML response") if raw_response.blank?

      response = parse_response(saml_configuration, raw_response, request_id)
      return failure(response.errors.join("; ").presence || "invalid SAML response") unless response.is_valid?

      organization = saml_configuration.organization
      asserted = asserted_fields(response, saml_configuration)
      error = resolution_error(organization:, **asserted.slice(:name_id, :email))
      return Result.new(error:, **asserted) if error

      # One lookup drives both the returning-user short-circuit and the post-login update.
      identity = SsoIdentity.for(organization:, provider:, uid: asserted[:name_id]) ||
        SsoIdentity.new(organization:, provider:, uid: asserted[:name_id])
      # Provisioning grants no organization role - that is user_role_for_user_email_domain's job.
      user, signed_up = identity.user ? [identity.user, false] :
        UserServices::PasswordlessCreator.find_or_create(asserted[:email])
      return Result.new(error: "no Bike Index account for #{asserted[:email]}", **asserted) if user.blank?
      # sign_in_and_redirect refuses a banned user too, but its redirect_back lands on the IdP
      # for an assertion, and the test page needs a reason it can show
      return Result.new(error: "#{asserted[:email]} is banned", **asserted) if user.banned?

      # The IdP vouched for this email, so confirm the account (as the magic-link path
      # does) — otherwise sign-in bounces an unconfirmed user to the confirm-email page.
      user.confirm(user.confirmation_token) unless user.confirmed?

      identity.update(user:, email: asserted[:email], name_id_format: asserted[:name_id_format],
        last_sign_in_at: Time.current)
      Result.new(user:, signed_up:, **asserted)
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

    def asserted_fields(response, saml_configuration)
      email_attribute = saml_configuration.email_attribute
      email = EmailNormalizer.normalize(response.attributes[email_attribute].presence || response.name_id)
      {name_id: response.name_id.presence, name_id_format: response.name_id_format,
       attributes: response.attributes.all, email_attribute:, email:,
       email_domain: Organization.email_domain(email)}
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

    def failure(message)
      Result.new(error: message)
    end

    conceal :provider, :parse_response, :asserted_fields, :resolution_error, :failure
  end
end
