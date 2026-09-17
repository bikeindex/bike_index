# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StepCombined::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:params) { {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}} }
  let(:b_param) { BParam.create(origin: "register_flow", params: params.as_json) }
  let(:component) do
    render_inline(described_class.new(b_param:, current_user: nil,
      steps: BikeServices::Register.steps(b_param, sequence: nil, single_page: true)))
  end

  def field_names(scope)
    component.css("form [name^='#{scope}[']").map { |el| el["name"] }.uniq
  end

  it "posts both steps from one form, each in the scope create reads it from" do
    expect(component).to have_css("form[action='/register'][method=post]")
    expect(field_names("b_param")).to include("b_param[manufacturer_id]", "b_param[owner_email]")
    expect(field_names("bike")).to include("bike[serial_number]", "bike[status]")

    # What tells create the submission carries step 2 as well
    expect(component.css("input[name=single_page]").count).to eq 1
    # One honeypot, not one per step
    expect(component.css("input[name=additional]").count).to eq 1
    # One segment in the progress bar - the page is the whole flow
    expect(component.css("span[class*='tw:h-1']").count).to eq 1
  end
end
