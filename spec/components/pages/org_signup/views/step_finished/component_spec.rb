# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::StepFinished::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization_signup:, current_user:)) }
  let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
  let(:current_user) { nil }

  it "registers for a shop's customers, and offers another link or address" do
    expect(component).to have_text "Register vehicles for your customers"
    expect(component).to have_button "Send it again"
    expect(component).to have_link "Change it", href: "/organizations/signup?change_email=true&step=1"
  end

  context "signed in" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "has no address to change" do
      expect(component).to have_button "Send it again"
      expect(component).to have_no_link "Change it"
    end
  end

  context "out of links" do
    let(:organization_signup) do
      FactoryBot.create(:organization_signup_details_completed, email_confirmations_sent: OrgServices::Signup::MAX_CONFIRMATION_EMAILS)
    end

    it "says so, with no way to ask for another" do
      expect(component).to have_text "We can't send another link"
      expect(component).to have_no_text "Check your email"
      expect(component).to have_no_button "Send it again"
      expect(component).to have_no_link "Change it"
    end
  end

  context "a school" do
    let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed, kind: "school") }

    it "registers for its students" do
      expect(component).to have_text "Register vehicles for your students and staff"
      expect(component).to have_no_text "customers"
    end
  end
end
