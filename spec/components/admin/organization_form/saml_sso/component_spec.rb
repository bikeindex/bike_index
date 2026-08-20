# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationForm::SamlSso::Component, type: :component do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso")
  end

  # render_in_view_context instance_execs its block, so the organization comes in as a local
  def rendered_component(organization)
    render_in_view_context do
      form_for [:admin, organization] do |f|
        render(Admin::OrganizationForm::SamlSso::Component.new(form_builder: f))
      end
    end
  end

  let(:component) { rendered_component(organization) }

  it "renders the service provider details and the SAML configuration fields" do
    expect(component).to have_content("SAML SSO")
    expect(component).to have_link(href: "http://test.host/sso/#{organization.to_param}/metadata")
    expect(component).to have_link(href: "http://test.host/sso/#{organization.to_param}/sp.crt")
    expect(component).to have_field("organization_organization_saml_configuration_attributes_idp_entity_id")
    expect(component).to have_field("organization_organization_saml_configuration_attributes_idp_cert")
    expect(component).to have_select("organization_organization_saml_configuration_attributes_name_id_format")
  end

  context "with an existing configuration" do
    before { organization.create_organization_saml_configuration(idp_entity_id: "https://idp.example.edu/") }

    it "renders its values rather than building a new one" do
      expect(component).to have_field("organization_organization_saml_configuration_attributes_idp_entity_id",
        with: "https://idp.example.edu/")
    end
  end
end
