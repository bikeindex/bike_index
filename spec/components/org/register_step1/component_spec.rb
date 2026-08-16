# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegisterStep1::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:b_param) do
    BParam.create(origin: "register_flow_organized",
      params: {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}}.as_json)
  end
  let(:instance) do
    described_class.new(b_param:, organization:,
      steps: BikeServices::Register.steps(b_param, sequence: nil))
  end
  let(:component) { render_inline(instance) }

  it "renders step 1 above the way back to the embed form" do
    expect(component).to have_css("form[action='/register']")
    # The organized menu names the organization, so the step doesn't
    expect(component.to_html).to_not include "Register your vehicle"

    # old_view is what stores the preference, so the menu keeps linking to the embed form
    expect(component).to have_link("Go back to the old view",
      href: "/o/#{organization.to_param}/bikes/new?old_view=true")
  end
end
