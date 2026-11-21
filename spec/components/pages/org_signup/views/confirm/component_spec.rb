# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::Confirm::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization_signup:, token: "sometoken", accept_terms:)) }
  let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
  let(:accept_terms) { false }

  it "posts the token, without asking about terms" do
    expect(component).to have_css("form[action='/organizations/signup/confirm_email'][method='post']")
    expect(component).to have_css("input[name='confirmation_token'][value='sometoken']", visible: :hidden)
    expect(component).to have_no_field("terms_of_service")
  end

  context "accept_terms" do
    let(:accept_terms) { true }

    it "requires agreeing to both sets of terms" do
      expect(component).to have_css("input[name='terms_of_service'][required]")
      expect(component).to have_link("Terms of Service", href: "/terms")
      expect(component).to have_link("Terms of Service for Organizations", href: "/vendor_terms")
    end
  end
end
