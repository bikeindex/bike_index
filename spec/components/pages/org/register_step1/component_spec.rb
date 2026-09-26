# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::RegisterStep1::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:b_param) do
    BParam.create(origin: "register_flow_organized",
      params: {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}}.as_json)
  end
  let(:single_page) { false }
  let(:instance) do
    described_class.new(b_param:, organization:,
      steps: BikeServices::Register.steps(b_param, sequence: nil, single_page:))
  end
  let(:component) { render_inline(instance) }

  it "renders step 1 above the switches that change the flow" do
    expect(component).to have_css("form[action='/register']")
    # The organized menu names the organization, so the step doesn't
    expect(component.to_html).to_not include "Register your vehicle"
    expect(component).to have_css("form[action='/register'] [name='bike[serial_number]']", count: 0)

    # old_view is what stores the preference, so the menu keeps linking to the embed form
    expect(component).to have_link("Go back to the old view",
      href: "/o/#{organization.to_param}/bikes/new?old_view=true")

    switches = component.at_css("form[action='/o/#{organization.to_param}/registrations/switches'][method=post]")
    expect(switches.css("input[type=checkbox]").map { |el| el["name"] })
      .to eq(%w[single_page separate_attestation])
    expect(switches.css("input[type=checkbox][checked]")).to be_empty
  end

  context "single_page" do
    let(:single_page) { true }

    it "asks for step 2's details on the same page, and checks the switch that did it" do
      expect(component).to have_css("form[action='/register'] [name='bike[serial_number]']")
      expect(component).to have_css("input[name=single_page][type=checkbox][checked]")
    end
  end
end
