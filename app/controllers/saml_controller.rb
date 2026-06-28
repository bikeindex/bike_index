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

  # SP-initiated login: redirect to the IdP with a signed AuthnRequest, remembering the
  # request id (replay protection) and org slug (cross-tenant binding) for the callback.
  def init
    settings = Saml::SettingsBuilder.build(configured_saml_configuration)
    auth_request = OneLogin::RubySaml::Authrequest.new
    redirect_url = auth_request.create(settings)
    session[:saml_request_id] = auth_request.request_id
    session[:saml_org_slug] = params[:org_slug]
    redirect_to redirect_url, allow_other_host: true
  end

  # Assertion Consumer Service: validate the IdP's response and sign the user in.
  def callback
    saml_configuration = configured_saml_configuration
    request_id = session.delete(:saml_request_id)
    return saml_failure("SAML session mismatch") if session.delete(:saml_org_slug) != params[:org_slug]

    result = Saml::AssertionProcessor.call(saml_configuration:,
      raw_response: params[:SAMLResponse], request_id:)
    return saml_failure(result.error) unless result.success?

    sign_in_and_redirect(result.user)
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
