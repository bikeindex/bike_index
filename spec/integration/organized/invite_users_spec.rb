# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized user invitations", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }

  before { sign_in(user) }

  it "swaps the single email for multiple" do
    visit new_organization_user_path(organization_id: organization.to_param)
    wait_for_stimulus("org--field-expander")

    expect(page).to have_field("Email you're inviting")
    expect(page).to have_no_field("multiple_emails_invited")

    click_button "Invite multiple emails"
    expect(page).to have_field("multiple_emails_invited")
    expect(page).to have_no_field("Email you're inviting")

    fill_in "multiple_emails_invited", with: "first@example.com\nsecond@example.com"
    choose "organization_role_role_member"
    expect {
      click_button "Send invitation"
      expect(page).to have_no_button("Send invitation")
    }
      .to change(OrganizationRole, :count).by 2
    expect(organization.organization_roles.pluck(:invited_email)).to include("first@example.com", "second@example.com")
  end
end
