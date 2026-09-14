# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Users::AcceptTerms::Component, type: :component do
  let(:component) { render_inline(described_class.new(user:, attribute: :vendor_terms_of_service, label: "I agree", submit_text: "Submit")) }
  let(:user) { FactoryBot.create(:user) }

  it "renders a required checkbox and a submit button, in the bar the page sticks to the bottom" do
    expect(component).to have_css("form[action='/users/#{user.to_param}'] input[name='_method'][value='patch']", visible: :all)
    expect(component).to have_css("input[type='checkbox'][name='user[vendor_terms_of_service]'][required]")
    expect(component).to have_css("button[type='submit']", text: "Submit")
    expect(component).to have_css("div.tw\\:sticky.tw\\:bottom-0")
  end
end
