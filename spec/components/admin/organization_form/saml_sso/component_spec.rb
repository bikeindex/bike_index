# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationForm::SamlSso::Component, type: :component do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso")
  end

  def rendered_component(organization)
    render_in_view_context do
      form_for [:admin, organization] do |f|
        render(Admin::OrganizationForm::SamlSso::Component.new(form_builder: f))
      end
    end
  end

  let(:component) { rendered_component(organization) }

  it "gives the IdP admin the service provider URLs" do
    expect(component).to have_link(href: "http://test.host/sso/#{organization.to_param}/metadata")
    expect(component).to have_link(href: "http://test.host/sso/#{organization.to_param}/sp.crt")
  end

  context "with an existing configuration" do
    before { organization.create_organization_saml_configuration(idp_entity_id: "https://idp.example.edu/") }

    it "renders its values rather than building a new one" do
      expect(component).to have_field("organization_organization_saml_configuration_attributes_idp_entity_id",
        with: "https://idp.example.edu/")
    end
  end
end
