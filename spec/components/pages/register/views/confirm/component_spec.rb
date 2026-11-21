# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Views::Confirm::Component, type: :component do
  let(:component) { render_inline(described_class.new(b_param:, token: "sometoken", accept_terms:)) }
  let(:accept_terms) { false }
  let(:b_param) { FactoryBot.create(:b_param, params: {bike: {owner_email: "someone@bikeindex.org"}}) }

  # Confirming is single use, and scanners run the page's JS
  it "posts the token, and waits for a click to do it" do
    expect(component).to have_css("form[action='/register/confirm_email'][method='post']")
    expect(component).to have_no_css("[data-controller='auto-submit']")
    expect(component).to have_css("input[name='confirmation_token'][value='sometoken']", visible: :hidden)
    expect(component).to have_css("input[name='b_param_token'][value='#{b_param.id_token}']", visible: :hidden)
    expect(component).to have_no_field("terms_of_service")
  end

  context "accept_terms" do
    let(:accept_terms) { true }

    it "requires agreeing to the terms" do
      expect(component).to have_field("I agree to Bike Index's Terms of Service", type: :checkbox)
      expect(component).to have_css("input[name='terms_of_service'][required]")
      expect(component).to have_link("Terms of Service", href: "/terms")
    end
  end
end
