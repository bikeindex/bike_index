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

  # Org-slug entry point for users whose email domain isn't auto-detected on the login form.
  # Submitting a slug that maps to a configured org forwards to #init.
  def login
    return if params[:org_slug].blank?

    organization = Organization.friendly_find(params[:org_slug])
    return redirect_to saml_init_path(org_slug: organization.to_param) if organization&.saml_sso_configured?

    flash.now[:error] = "We couldn't find single sign-on for that organization"
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
    expected_slug = session.delete(:saml_org_slug)
    # No remembered request means this assertion wasn't solicited by us — IdP-initiated.
    idp_initiated = expected_slug.blank?

    if idp_initiated
      return saml_failure("IdP-initiated login isn't enabled for this organization") unless saml_configuration.allow_idp_initiated?
    elsif expected_slug != params[:org_slug]
      return saml_failure("SAML session mismatch")
    end

    result = Saml::AssertionProcessor.call(saml_configuration:,
      raw_response: params[:SAMLResponse], request_id:, idp_initiated:)
    return saml_failure(result.error) unless result.success?

    remember_saml_session(result)
    sign_in_and_redirect(result.user)
  end

  # SP-initiated Single Logout. We sign the user out of Bike Index immediately, then
  # best-effort notify the IdP with a signed LogoutRequest. SLO is inconsistently
  # implemented across IdPs, so when we can't build a valid request we just land on goodbye.
  def logout
    organization = Organization.friendly_find(params[:org_slug])
    redirect_url = saml_logout_request_url(organization&.organization_saml_configuration)
    remove_session
    return redirect_to(redirect_url, allow_other_host: true) if redirect_url

    redirect_to goodbye_url, notice: "Logged out!"
  end

  # Single Logout endpoint (HTTP-Redirect binding): either an IdP-initiated LogoutRequest,
  # or the IdP's LogoutResponse to a logout we started (we've already cleared our session).
  def slo
    return redirect_to(goodbye_url, notice: "Logged out!") if params[:SAMLRequest].blank?

    handle_idp_logout_request
  end

  private

  def handle_idp_logout_request
    saml_configuration = configured_saml_configuration
    return saml_failure("logout request is not signed") if params[:Signature].blank?

    settings = Saml::SettingsBuilder.build(saml_configuration)
    logout_request = OneLogin::RubySaml::SloLogoutrequest.new(params[:SAMLRequest],
      settings:, get_params: request.query_parameters, raw_get_params: raw_query_params)
    unless logout_request.is_valid?
      return saml_failure(logout_request.errors.join("; ").presence || "invalid logout request")
    end

    remove_session
    return redirect_to(goodbye_url, notice: "Logged out!") unless saml_configuration.slo_configured?

    redirect_to OneLogin::RubySaml::SloLogoutresponse.new.create(settings, logout_request.id),
      allow_other_host: true
  end

  def saml_logout_request_url(saml_configuration)
    saml_logout = session[:saml_logout]&.symbolize_keys
    return nil unless saml_configuration&.slo_configured? && saml_logout.present?

    settings = Saml::SettingsBuilder.build(saml_configuration)
    settings.name_identifier_value = saml_logout[:name_id]
    settings.name_identifier_format = saml_logout[:name_id_format]
    settings.sessionindex = saml_logout[:session_index]
    OneLogin::RubySaml::Logoutrequest.new.create(settings)
  end

  # Remember what a later LogoutRequest to the IdP needs to identify this session.
  def remember_saml_session(result)
    session[:saml_logout] = {org_slug: params[:org_slug], name_id: result.name_id,
      name_id_format: result.name_id_format, session_index: result.session_index}
  end

  # Raw (still URI-encoded) query parts, so ruby-saml verifies the redirect-binding
  # signature against exactly what the IdP signed.
  def raw_query_params
    request.query_string.split("&").each_with_object({}) do |pair, hash|
      key, value = pair.split("=", 2)
      hash[key] = value
    end
  end

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
