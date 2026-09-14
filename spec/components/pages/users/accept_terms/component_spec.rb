# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Users::AcceptTerms::Component, type: :component do
  let(:component) { render_inline(described_class.new(user:, attribute: :vendor_terms_of_service, label: "I agree", submit_text: "Submit")) { "the terms" } }
  let(:user) { FactoryBot.create(:user) }

  it "patches the user with a required checkbox" do
    expect(component).to have_css("form[action='/users/#{user.to_param}'] input[name='_method'][value='patch']", visible: :all)
    expect(component).to have_css("input[type='checkbox'][name='user[vendor_terms_of_service]'][required]")
    expect(component).to have_css("button[type='submit']", text: "Submit")
  end
end
