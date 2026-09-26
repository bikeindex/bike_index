# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StepCombined::Component, type: :component do
  let(:b_param) { BParam.create(origin: "register_flow", params: {bike: {owner_email: "owner@bikeindex.org"}}.as_json) }

  it "renders nothing when step 2 has a page of its own" do
    component = render_inline(described_class.new(b_param:, flow: BikeServices::Register.flow(b_param, sequence: nil)))

    expect(component.to_html).to be_blank
  end
end
