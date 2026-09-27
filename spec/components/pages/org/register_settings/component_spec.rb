# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::RegisterSettings::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:options) { {organization:} }
  let(:component) { render_inline(described_class.new(**options)) }
  let(:switches) { component.at_css("form[action='/o/#{organization.to_param}/registrations/switches'][method=post]") }

  it "renders the switches, and the way back to the old view" do
    expect(component).to have_css("h1", text: "Register settings")
    # old_view is what stores the preference, so the menu keeps linking to the embed form
    expect(component).to have_link("Go back to the old view",
      href: "/o/#{organization.to_param}/bikes/new?old_view=true")

    # No safety rules here, so nothing to leave to the registrant
    expect(switches.css("input[type=checkbox]").map { it["name"] }).to eq(%w[single_page])
    expect(switches.css("input[type=checkbox][checked]")).to be_empty
  end

  context "with an active registration sequence, and both set" do
    let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let(:options) { {organization:, single_page: true, separate_attestation: true} }

    it "offers the separate attestation switch as well, checking both" do
      expect(switches.css("input[type=checkbox][checked]").map { it["name"] })
        .to eq(%w[single_page separate_attestation])
    end
  end
end
