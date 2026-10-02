# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::RegisterSettings::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:options) { {organization:} }
  let(:component) { render_inline(described_class.new(**options)) }
  let(:switches) { component.at_css("form[action='/o/#{organization.to_param}/registrations/switches'][method=post]") }

  it "renders the switches" do
    expect(component).to have_css("h1", text: "Registration form settings")
    expect(component).to have_text "These settings are just applied to your browser"

    # No safety rules here, so nothing to leave to the registrant
    expect(switches.css("input[type=checkbox]").map { it["name"] }).to eq(%w[old_view single_page])
    expect(switches.css("input[type=checkbox][checked]")).to be_empty
  end

  context "organization admin" do
    let!(:auto_user) { FactoryBot.create(:organization_auto_user, organization:) }
    let(:options) { {organization: organization.reload, organization_admin: true} }

    it "renders the organization's email setting" do
      form = component.at_css("form[action='/o/#{organization.to_param}/manage']")
      expect(form.css("input[type=checkbox]").map { it["name"] }).to eq(["organization[send_self_registration_email]"])
      expect(form.css("input[type=checkbox][checked]")).to be_empty
      expect(form.at_css("code").text).to eq auto_user.email
    end

    context "not an admin" do
      let(:options) { {organization: organization.reload} }
      it "doesn't render the organization's email setting" do
        expect(component).to have_css("form", count: 1)
      end
    end
  end

  context "with an active registration sequence, and both set" do
    let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let(:options) { {organization:, old_view: true, single_page: true, separate_attestation: true} }

    it "offers the separate attestation switch as well, checking all three" do
      expect(switches.css("input[type=checkbox][checked]").map { it["name"] })
        .to eq(%w[old_view single_page separate_attestation])
    end
  end
end
