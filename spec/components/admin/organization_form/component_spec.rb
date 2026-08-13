# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationForm::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:superuser) }

  def rendered_component(organization, current_user)
    render_in_view_context do
      form_for [:admin, organization] do |f|
        render(Admin::OrganizationForm::Component.new(form_builder: f, organization:, current_user:))
      end
    end
  end

  let(:component) { rendered_component(organization, current_user) }

  it "renders the organization fields" do
    expect(component).to have_field("organization_name")
    expect(component).to have_field("organization_short_name")
    expect(component).to have_field("organization_website")
    expect(component).to have_field("organization_ascend_name")
    expect(component).to have_select("organization_kind")
    expect(component).to have_field("organization_available_invitation_count")
    expect(component).to have_field("organization_approved", type: "checkbox")
    expect(component).not_to have_field("organization_previous_slug")
  end

  context "with passwordless_users enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "passwordless_users")
    end

    it "renders the permitted domain rather than the invitation count, disabled for a non-developer" do
      expect(component).not_to have_field("organization_available_invitation_count")
      expect(component).to have_content("permitted domain for passwordless sign in")
      expect(component).to have_field("organization_user_email_domain", disabled: true)
      expect(component).to have_content("Ask Seth for help changing this")
    end

    context "with a developer current_user" do
      let(:current_user) { FactoryBot.create(:superuser_developer) }

      it "enables the domain field" do
        expect(component).to have_field("organization_user_email_domain", disabled: false)
        expect(component).not_to have_content("Ask Seth for help changing this")
      end
    end
  end

  context "with official_manufacturer enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "official_manufacturer")
    end

    it "renders the manufacturer combobox" do
      expect(component).to have_content("Official manufacturer organization")
      expect(component).to have_css("[name='organization[manufacturer_id]']", visible: :all)
    end
  end

  context "with saml_sso enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso")
    end

    it "renders the SAML configuration fields" do
      expect(component).to have_content("SAML SSO")
      expect(component).to have_link(href: /sso\/#{organization.to_param}\/metadata/)
      expect(component).to have_field("organization_organization_saml_configuration_attributes_idp_entity_id")
      expect(component).to have_field("organization_organization_saml_configuration_attributes_idp_cert")
    end
  end

  context "with organization_stolen_message enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "organization_stolen_message")
    end

    it "renders the stolen message settings, with the area radius hidden" do
      expect(component).to have_select("organization_stolen_message_kind")
      expect(component).to have_css("[data-admin--organization-form-target='stolenMessageArea'].tw\\:hidden\\!")
      expect(component).to have_field("organization_stolen_message_search_radius_miles")
    end

    context "with an area message" do
      before { OrganizationStolenMessage.for(organization).update(kind: "area") }

      it "renders the area radius shown" do
        expect(component).to have_css("[data-admin--organization-form-target='stolenMessageArea']")
        expect(component).not_to have_css("[data-admin--organization-form-target='stolenMessageArea'].tw\\:hidden\\!")
      end
    end
  end

  context "with a new organization" do
    let(:organization) { Organization.new }

    it "skips the auto user email" do
      expect(component).to have_field("organization_name")
      expect(component).not_to have_field("organization_embedable_user_email")
    end
  end
end
