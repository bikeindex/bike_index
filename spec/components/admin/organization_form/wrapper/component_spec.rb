# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationForm::Wrapper::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:superuser) }

  def rendered_component(organization, current_user)
    render_in_view_context do
      form_for [:admin, organization] do |f|
        render(Admin::OrganizationForm::Wrapper::Component.new(form_builder: f, current_user:))
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

  it "renders every field through the UI::Forms components" do
    expect(component).to have_css("#organization_name.twinput")
    expect(component).to have_css("#organization_kind.twinput")
    expect(component).to have_css("label.twlabel[for='organization_name']")
    # UI::Forms::Checkbox wraps its input in the label, rather than a sibling label + for
    expect(component).to have_css("label.twlabel #organization_approved")
    expect(component).not_to have_css(".form-control")
  end

  it "keeps the label's own note in the label, and what followed the field as helper text" do
    expect(component.at_css("label[for='organization_parent_organization_id']").text.squish)
      .to eq "Parent organization (probably) do not add parents! Parents must be part of the same organization optional"
    expect(component.at_css("#organization_parent_organization_id_helper").text.squish)
      .to start_with "Use the \"regional\" feature instead."
  end

  it "points every field at its helper text" do
    described = component.css("[aria-describedby]").map { |field| field["aria-describedby"] }
    expect(described).to include "organization_parent_organization_id_helper"
    # Every id referenced resolves, and every helper <p> is referenced by something
    expect(described.reject { |id| component.at_css("##{id}") }).to be_empty
    helper_ids = component.css("p[id$='_helper']").map { |paragraph| paragraph["id"] }
    expect(helper_ids - described).to be_empty
  end

  context "with passwordless_users enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "passwordless_users")
    end
    let(:domain_field) { component.at_css("#organization_user_email_domain") }
    let(:domain_helper_text) { component.at_css("##{domain_field["aria-describedby"]}") }

    it "renders the permitted domain rather than the invitation count, disabled for a non-developer" do
      expect(component).not_to have_field("organization_available_invitation_count")
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

  context "with official_manufacturer enabled" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "official_manufacturer")
    end

    it "renders the manufacturer combobox, pointed at its helper text" do
      expect(component).to have_content("Official manufacturer organization")
      expect(component).to have_css("[name='organization[manufacturer_id]']", visible: :all)
      expect(component.at_css("input[role='combobox'][aria-describedby='organization_manufacturer_id_helper']"))
        .to be_present
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

  describe "locations" do
    let!(:location) { FactoryBot.create(:location, organization:, name: "Main Office") }

    it "renders the location fields, and a blank set in the nested-fields template" do
      expect(component).to have_field("organization_locations_attributes_0_name", with: "Main Office")
      expect(component).to have_field("organization_locations_attributes_0_address_record_attributes_city")

      # ui--forms--nested-fields clones this into the page, so it has to be exactly one blank location
      template = Nokogiri::HTML.fragment(component.at_css("template").inner_html)
      expect(template.css(".card").length).to eq 1
      expect(template.css("input.twinput[name*='locations_attributes']").length).to be > 1
      expect(template.css("[name='organization[name]']")).to be_empty
      expect(template.text).not_to match "Main Office"
    end
  end

  context "with a new organization" do
    let(:organization) { Organization.new }

    it "skips the auto user email and the locations" do
      expect(component).to have_field("organization_name")
      expect(component).not_to have_field("organization_embedable_user_email")
      expect(component).not_to have_css("[data-controller='ui--forms--nested-fields']")
    end
  end
end
