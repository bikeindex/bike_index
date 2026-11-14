# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::Confirm::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization_signup:, token: "token")) }
  let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }

  it "names the address it's activating, with a spinner on the button" do
    expect(component).to have_css "strong", text: "org_admin@bikeindex.org"
    expect(component).to have_css "button[data-controller~='ui--button--submit-spinner']", text: "Activate"
  end
end
