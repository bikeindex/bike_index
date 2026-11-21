# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Views::Confirm::Component, type: :component do
  let(:component) {
    render_inline(described_class.new(b_param:, token: "sometoken", accept_terms:, terms_checked:,
      signed_in_as:, sign_out_to_agree:))
  }
  let(:accept_terms) { false }
  let(:terms_checked) { false }
  let(:signed_in_as) { nil }
  let(:sign_out_to_agree) { false }
  let(:b_param) { FactoryBot.create(:b_param, params: {bike: {owner_email: "someone@bikeindex.org"}}) }

  # Confirming is single use, and scanners run the page's JS
  it "posts the token, and waits for a click to do it" do
    expect(component).to have_css("form[action='/register/confirm_email'][method='post']")
    expect(component).to have_no_css("[data-controller='auto-submit']")
    expect(component).to have_css("input[name='confirmation_token'][value='sometoken']", visible: :hidden)
    expect(component).to have_css("input[name='b_param_token'][value='#{b_param.id_token}']", visible: :hidden)
    expect(component).to have_no_field("terms_of_service")
    expect(component).to have_no_css("[role='alert']")
  end

  context "accept_terms" do
    let(:accept_terms) { true }

    it "requires agreeing to the terms" do
      expect(component).to have_field("I agree to Bike Index's Terms of Service", type: :checkbox, checked: false)
      expect(component).to have_css("input[name='terms_of_service'][required]")
      expect(component).to have_link("Read the Terms of Service", href: "/terms")
      # A tap on the label ticks the box rather than opening the terms
      expect(component).to have_no_css("label a")
    end

    context "terms_checked" do
      let(:terms_checked) { true }

      it "comes back ticked" do
        expect(component).to have_checked_field("I agree to Bike Index's Terms of Service")
      end
    end
  end

  context "signed_in_as" do
    let(:signed_in_as) { "someone-else@bikeindex.org" }

    it "warns that the registration finishes in their account" do
      expect(component).to have_css("dd", text: "someone-else@bikeindex.org")
      expect(component).to have_css("dd", text: "someone@bikeindex.org")
      expect(component).to have_css("[role='alert']", text: "Continuing keeps you signed in")
      expect(component).to have_button("Continue")
    end

    context "sign_out_to_agree" do
      let(:sign_out_to_agree) { true }

      it "says to sign out, with nothing to submit" do
        expect(component).to have_css("[role='alert']", text: "Sign out, then open the link again")
        expect(component).to have_no_button("Continue")
      end
    end
  end
end
