# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::StepFinished::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization_signup:)) }
  let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }

  it "registers for a shop's customers" do
    expect(component).to have_text "Register vehicles for your customers"
  end

  context "a school" do
    let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed, kind: "school") }

    it "registers for its students" do
      expect(component).to have_text "Register vehicles for your students and staff"
      expect(component).to have_no_text "customers"
    end
  end
end
