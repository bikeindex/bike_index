# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Organizations::Form::FeatureSettings::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:superuser) }

  def rendered_component(organization, current_user)
    render_in_view_context do
      form_for [:admin, organization] do |f|
        render(Pages::Admin::Organizations::Form::FeatureSettings::Component.new(form_builder: f, current_user:))
      end
    end
  end

  let(:component) { rendered_component(organization, current_user) }

  context "with passwordless_users enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "passwordless_users")
    end
    let(:domain_field) { component.at_css("#organization_user_email_domain") }
    let(:domain_helper_text) { component.at_css("##{domain_field["aria-describedby"]}") }

    it "renders the permitted domain, disabled for a non-developer" do
      expect(component).to have_field("organization_user_email_domain", disabled: true)
      expect(component.at_css("label[for='organization_user_email_domain']").text.squish)
        .to eq "permitted domain for passwordless sign in passwordless sign in feature optional"
      expect(domain_helper_text.text.squish).to eq "Ask Seth for help changing this, it's delicate"
      # the "@" is a prefix on the field, not a line of its own above it
      expect(domain_field.parent.name).to eq "div"
      expect(domain_field.parent.at_css("span").text).to eq "@"
    end

    context "with saml_sso also enabled" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: %w[passwordless_users saml_sso])
      end

      it "separates the feature names" do
        label = component.at_css("label[for='organization_user_email_domain']")
        expect(label.text.squish).to match(/passwordless sign in feature SAML SSO feature/)
      end
    end

    context "with a developer current_user" do
      let(:current_user) { FactoryBot.create(:superuser_developer) }

      it "enables the domain field, without pointing it at absent helper text" do
        expect(component).to have_field("organization_user_email_domain", disabled: false)
        expect(component).not_to have_content("Ask Seth for help changing this")
        expect(domain_field["aria-describedby"]).to be_nil
      end
    end
  end

  context "with every customizable registration label" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features,
        enabled_feature_slugs: OrganizationFeature.reg_fields_with_customizable_labels)
    end

    it "gives each one its own helper text" do
      expect(component).to have_field("reg_label-reg_phone")
      expect(component.at_css("#reg_label-reg_phone_helper").text.squish)
        .to eq "leave blank unless it's absolutely required - default behavior is preferred"
      expect(component.at_css("#reg_label-reg_phone")["aria-describedby"]).to eq "reg_label-reg_phone_helper"
      # The email fields say something different
      expect(component.at_css("#reg_label-owner_email_helper").text.squish).to eq "often desired by universities"
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
      # A top-level param, so the label points at the bare name, not an organization-scoped id
      expect(component).to have_css("label[for='organization_stolen_message_search_radius_miles']")
    end

    context "with an area message" do
      before { OrganizationStolenMessage.for(organization).update(kind: "area") }

      it "renders the area radius shown" do
        expect(component).to have_css("[data-admin--organization-form-target='stolenMessageArea']")
        expect(component).not_to have_css("[data-admin--organization-form-target='stolenMessageArea'].tw\\:hidden\\!")
      end
    end
  end

  context "with saml_sso enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso")
    end

    it "leaves the SAML configuration to its own tab" do
      expect(component).to have_field("organization_user_email_domain", disabled: true)
      expect(component).not_to have_field("organization_organization_saml_configuration_attributes_idp_entity_id")
    end
  end
end
