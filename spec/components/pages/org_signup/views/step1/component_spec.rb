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
    expect(kinds.index("municipality")).to eq kinds.index("school") + 1
    expect(kinds.last).to eq "other"
  end

  context "signed in" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "names their account rather than asking" do
      expect(component).to have_no_field("organization_signup[email]")
      expect(component).to have_text("You're signed in as #{current_user.email}")
      expect(component).to have_no_text("You're already part of")
    end

    context "already part of an organization" do
      let(:current_user) { FactoryBot.create(:organization_role_claimed).user }

      it "says this makes a separate one" do
        expect(component).to have_text("You're already part of #{current_user.organizations.first.short_name} - this creates a separate organization.")
      end
    end
  end

  context "a brand new signup" do
    let(:organization_signup) { FactoryBot.create(:organization_signup) }

    it "has nothing to start over from" do
      expect(component).to have_no_link("Start a different organization instead")
    end
  end

  # Every signup link resumes this one, so starting another has to be offered here
  it "offers starting a different organization" do
    expect(component).to have_link("Start a different organization instead", href: "/organizations/signup/new?restart=true")
  end
end
