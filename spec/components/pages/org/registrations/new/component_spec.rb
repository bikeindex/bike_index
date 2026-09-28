# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Registrations::New::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:b_param) do
    BParam.create(origin: "register_flow_organized",
      params: {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}}.as_json)
  end
  let(:instance) do
    described_class.new(b_param:, organization:,
      flow: BikeServices::Register.flow(b_param, sequence: nil))
  end
  let(:component) { render_inline(instance) }

  it "renders step 1 above a link to the settings that change the flow" do
    expect(component).to have_css("form[action='/register']")
    # The organized menu names the organization, so the step doesn't
    expect(component.to_html).to_not include "Register your vehicle"
    expect(component).to have_css("form[action='/register'] [name='bike[serial_number]']", count: 0)

    expect(component).to have_link("Registration form settings",
      href: "/o/#{organization.to_param}/registrations/settings")
  end
end
