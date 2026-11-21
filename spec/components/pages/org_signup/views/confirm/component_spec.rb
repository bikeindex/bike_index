# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::Confirm::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization_signup:, token: "sometoken", accept_terms:, signed_in_as:)) }
  let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
  let(:accept_terms) { false }
  let(:signed_in_as) { nil }

  it "posts the token, without asking about terms" do
    expect(component).to have_css("form[action='/organizations/signup/confirm_email'][method='post']")
    expect(component).to have_css("input[name='confirmation_token'][value='sometoken']", visible: :hidden)
    expect(component).to have_no_field("terms_of_service")
    expect(component).to have_no_css("[role='alert']")
    expect(component).to have_button("Activate")
  end

  context "accept_terms" do
    let(:accept_terms) { true }

    it "requires agreeing to both sets of terms" do
      expect(component).to have_field("I agree to Bike Index's Terms of Service and Terms of Service for Organizations",
        type: :checkbox)
      expect(component).to have_css("input[name='terms_of_service'][required]")
      # A tap on the label ticks the box rather than opening the terms
      expect(component).to have_no_css("label a")
      expect(component).to have_link("Terms of Service", href: "/terms")
      expect(component).to have_link("Terms of Service for Organizations", href: "/vendor_terms")
    end
  end

  context "signed_in_as" do
    let(:signed_in_as) { "someone-else@bikeindex.org" }

    it "warns that activating signs them out" do
      expect(component).to have_css("dd", text: "someone-else@bikeindex.org")
      expect(component).to have_css("dd", text: organization_signup.email)
      expect(component).to have_css("[role='alert']", text: "Activating signs you out of it")
      expect(component).to have_button("Sign out and activate")
    end
  end
end
