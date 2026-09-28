# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::Confirm::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization_signup:, token: "sometoken")) }
  let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }

  # Confirming is single use, and scanners run the page's JS
  it "posts the token, and waits for a click to do it" do
    expect(component).to have_css("form[action='/organizations/signup/confirm_email'][method='post']")
    expect(component).to have_css("input[name='confirmation_token'][value='sometoken']", visible: :hidden)
    expect(component).to have_css("input[name='signup_token'][value='#{organization_signup.id_token}']", visible: :hidden)
  end
end
