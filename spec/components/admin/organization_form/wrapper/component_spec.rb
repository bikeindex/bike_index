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

    it "drops the invitation count, which the permitted domain stands in for" do
      expect(component).not_to have_field("organization_available_invitation_count")
      expect(component).to have_content("permitted domain with passwordless sign in")
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

  context "with a new organization" do
    let(:organization) { Organization.new }

    it "skips the auto user email" do
      expect(component).to have_field("organization_name")
      expect(component).not_to have_field("organization_embedable_user_email")
    end
  end
end
