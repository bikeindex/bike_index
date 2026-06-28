class SamlController < ApplicationController
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
end
