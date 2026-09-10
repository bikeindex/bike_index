# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StepConfirm::Component, type: :component do
  let(:component) { render_inline(described_class.new(b_param:, token: "sometoken")) }
  let(:b_param) { FactoryBot.create(:b_param, params: {bike: {owner_email: "someone@bikeindex.org"}}) }

  # Confirming is single use, and scanners run the page's JS
  it "posts the token, and waits for a click to do it" do
    expect(component).to have_css("form[action='/register/confirm_email'][method='post']")
    expect(component).to have_no_css("[data-controller='auto-submit']")
    expect(component).to have_css("input[name='confirmation_token'][value='sometoken']", visible: :hidden)
    expect(component).to have_css("input[name='b_param_token'][value='#{b_param.id_token}']", visible: :hidden)
  end
end
