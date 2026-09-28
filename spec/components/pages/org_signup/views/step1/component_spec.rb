# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::Step1::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization_signup:, current_user:)) }
  let(:organization_signup) { FactoryBot.create(:organization_signup_started) }
  let(:current_user) { nil }

  it "asks for the email, and offers only the kinds a user can create" do
    expect(component).to have_field("organization_signup[name]", with: "Shifty Bike Shop")
    expect(component).to have_field("organization_signup[email]", with: "org_admin@bikeindex.org")
    expect(component).to have_checked_field("Bike shop", visible: :all)
    kinds = component.css("input[name='organization_signup[kind]']").map { it["value"] }
    expect(kinds).to match_array(Organization.user_creatable_kinds)
  end

  context "signed in" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "names their account rather than asking" do
      expect(component).to have_no_field("organization_signup[email]")
      expect(component).to have_text("You're signed in as #{current_user.email}")
    end
  end
end
