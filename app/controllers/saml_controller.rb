class SamlController < ApplicationController
  include Sessionable

  # The IdP POSTs the assertion with no CSRF token; replay protection comes from the
  # signed InResponseTo + one-time request id, not from CSRF.
  skip_before_action :verify_authenticity_token, only: :callback

  # SP metadata is public by design — it carries only our entityID, ACS URL, and the
  # public SP certificate (never the private key). IdP admins consume it during onboarding.
  def metadata
    organization = Organization.friendly_find(params[:org_slug])
    raise ActiveRecord::RecordNotFound unless organization&.enabled?("saml_sso")

    # build_ (not fetch_) so a GET never persists a configuration record
    saml_configuration = organization.organization_saml_configuration ||
      organization.build_organization_saml_configuration
    settings = Saml::SettingsBuilder.build(saml_configuration)

    render body: OneLogin::RubySaml::Metadata.new.generate(settings, true),
      content_type: "application/samlmetadata+xml"
  end

  # SP-initiated login: redirect to the IdP with a signed AuthnRequest, parking the request id
  # (replay protection) and org slug (cross-tenant binding) in RelayState for the callback.
  def init
    settings = Saml::SettingsBuilder.build(configured_saml_configuration)
    auth_request = OneLogin::RubySaml::Authrequest.new
    relay_state = Saml::RequestStore.create(request_id: auth_request.request_id,
      org_slug: params[:org_slug])
    redirect_to auth_request.create(settings, RelayState: relay_state), allow_other_host: true
  end

  # Assertion Consumer Service: validate the IdP's response and sign the user in.
  def callback
    saml_configuration = configured_saml_configuration
    # RelayState is a bearer token, not bound to the browser that began the login, so an attacker
    # can hand their own token and assertion to a victim and land them in the attacker's account.
    # Accepted: binding it needs a cookie that survives the IdP's cross-site POST, and that
    # fragility is what kept SSO login from working at all. No victim account is taken over.
    saml_request = Saml::RequestStore.claim(params[:RelayState])
    return saml_failure("this login has expired, please try again") if saml_request.blank?
    return saml_failure("SAML session mismatch") if saml_request[:org_slug] != params[:org_slug]

    result = Saml::AssertionProcessor.call(saml_configuration:,
      raw_response: params[:SAMLResponse], request_id: saml_request[:request_id])
    return saml_failure(result.error) unless result.success?

    sign_in_and_redirect(result.user, via_saml: true)
  end

  private

  def configured_saml_configuration
    organization = Organization.friendly_find(params[:org_slug])
    saml_configuration = organization&.organization_saml_configuration
    raise ActiveRecord::RecordNotFound unless organization&.enabled?("saml_sso") && saml_configuration&.configured?

    saml_configuration
  end

  def saml_failure(message)
    flash[:error] = "Unable to sign in via SSO: #{message}"
    redirect_to new_session_path
  end
end
