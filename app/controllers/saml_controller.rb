class SamlController < ApplicationController
  include Sessionable

  # The IdP POSTs the assertion with no CSRF token; replay protection comes from the
  # signed InResponseTo + one-time request id, not from CSRF.
  skip_before_action :verify_authenticity_token, only: :callback

  # SP metadata is public by design — it carries only our entityID, ACS URL, and the
  # public SP certificate (never the private key). IdP admins consume it during onboarding.
  def metadata
    settings = Saml::SettingsBuilder.build(published_saml_configuration)
    # application/samlmetadata+xml is the registered type, but browsers download an unknown
    # type instead of showing it, and this url is one we hand to a person
    render body: OneLogin::RubySaml::Metadata.new.generate(settings, true),
      content_type: "application/xml"
  end

  # Some IdP tooling registers a bare certificate rather than reading one out of metadata.
  # The keypair is app-wide, so the org-scoped path serves the same bytes for every org
  def certificate
    sp_certificate = Saml::SettingsBuilder.build(published_saml_configuration).certificate
    raise ActiveRecord::RecordNotFound if sp_certificate.blank?

    render body: sp_certificate, content_type: "application/pem-certificate-chain"
  end

  # SP-initiated login: redirect to the IdP with a signed AuthnRequest, parking the request id
  # (replay protection) and org slug (cross-tenant binding) in RelayState for the callback.
  def init
    redirect_to_saml(configured_saml_configuration)
  end

  # A rehearsal of the login the organization's users will get: the same transaction,
  # landing on a page that reports what the IdP sent rather than where they were headed
  def test
    render_saml_test(configured_saml_configuration)
  end

  def test_start
    saml_configuration = configured_saml_configuration
    email = EmailNormalizer.normalize(params[:email])
    if email.blank?
      flash.now[:error] = "Enter the email address to sign in with"
      return render_saml_test(saml_configuration)
    end

    redirect_to_saml(saml_configuration, mode: Saml::RequestStore::TEST_MODE, expected_email: email)
  end

  # Assertion Consumer Service: validate the IdP's response and sign the user in.
  def callback
    # RelayState is a bearer token, not bound to the browser that began the login, so an attacker
    # can hand their own token and assertion to a victim and land them in the attacker's account.
    # Accepted: binding it needs a cookie that survives the IdP's cross-site POST, and that
    # fragility is what kept SSO login from working at all. No victim account is taken over.
    saml_request = Saml::RequestStore.claim(params[:RelayState])
    return saml_failure("this login has expired, please try again") if saml_request.blank?
    return saml_failure("SAML session mismatch") if saml_request[:org_slug] != params[:org_slug]

    saml_configuration = configured_saml_configuration
    result = Saml::AssertionProcessor.call(saml_configuration:,
      raw_response: params[:SAMLResponse], request_id: saml_request[:request_id])

    if saml_request[:mode] == Saml::RequestStore::TEST_MODE
      sign_in_user(result.user) if result.success?
      return render_saml_test(saml_configuration, result:, expected_email: saml_request[:expected_email])
    end
    return saml_failure(result.error) unless result.success?

    session[:return_to] = saml_request[:return_to]
    sign_in_and_redirect(result.user, via_saml: true)
  end

  private

  def saml_organization
    organization = Organization.friendly_find(params[:org_slug])
    raise ActiveRecord::RecordNotFound unless organization&.enabled?("saml_sso")

    organization
  end

  # build_ (not fetch_) so a GET never persists a configuration record
  def published_saml_configuration
    organization = saml_organization
    organization.organization_saml_configuration || organization.build_organization_saml_configuration
  end

  def configured_saml_configuration
    saml_configuration = saml_organization.organization_saml_configuration
    raise ActiveRecord::RecordNotFound unless saml_configuration&.configured?

    saml_configuration
  end

  def redirect_to_saml(saml_configuration, mode: Saml::RequestStore::NORMAL_MODE, expected_email: nil)
    settings = Saml::SettingsBuilder.build(saml_configuration)
    auth_request = OneLogin::RubySaml::Authrequest.new
    # This leg is same-site, so the session is readable here; the callback's isn't, so where
    # the user was headed has to travel with the rest of the transaction
    relay_state = Saml::RequestStore.create(request_id: auth_request.request_id,
      org_slug: params[:org_slug], return_to: session[:return_to], mode:, expected_email:)
    redirect_to auth_request.create(settings, RelayState: relay_state), allow_other_host: true
  end

  def render_saml_test(saml_configuration, **component_options)
    @page_title = "SAML configuration test"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    render Saml::Test::Component.new(organization: saml_configuration.organization, **component_options)
  end

  def saml_failure(message)
    flash[:error] = "Unable to sign in via SSO: #{message}"
    redirect_to new_session_path
  end
end
