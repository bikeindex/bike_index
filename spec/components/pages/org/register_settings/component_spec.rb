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

  context "with an active registration sequence, and both set" do
    let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let(:options) { {organization:, old_view: true, single_page: true, separate_attestation: true} }

    it "offers the separate attestation switch as well, checking all three" do
      expect(switches.css("input[type=checkbox][checked]").map { it["name"] })
        .to eq(%w[old_view single_page separate_attestation])
    end
  end

  context "with parking notifications, and the old unregistered notification page set" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications]) }
    let(:options) { {organization:, old_unregistered_notification_view: true} }

    it "offers it below the form options, outside the old registration page's reach" do
      expect(component).to have_text "Unregistered Notification page"
      expect(switches.css("input[type=checkbox]").map { it["name"] })
        .to eq(%w[old_view single_page old_unregistered_notification_view])
      expect(switches.css("input[type=checkbox][checked]").map { it["name"] }).to eq(%w[old_unregistered_notification_view])
      expect(switches.at_css("input[name=old_unregistered_notification_view]")["data-org--register-settings-target"]).to be_nil
    end
  end
end
