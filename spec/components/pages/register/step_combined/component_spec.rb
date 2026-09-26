# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StepCombined::Component, type: :component do
  let(:b_param) { BParam.create(origin: "register_flow", params: {bike: {owner_email: "owner@bikeindex.org"}}.as_json) }
  let(:single_page) { true }
  let(:component) do
    render_inline(described_class.new(b_param:,
      flow: BikeServices::Register.flow(b_param, sequence: nil, single_page:)))
  end

  it "tells create both steps are here, and asks for step 2's details" do
    expect(component.css("input[name=single_page]").count).to eq 1
    expect(component).to have_css("[name='bike[serial_number]']")
    expect(component).to have_css("button[type=submit]")
  end

  context "with a step 2 page of its own" do
    let(:single_page) { false }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
