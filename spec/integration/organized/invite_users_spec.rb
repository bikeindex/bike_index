# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized user invitations", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization, available_invitation_count: 3) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }

  before { sign_in(user) }

  it "validates the emails as they're typed, then invites them" do
    visit new_organization_user_path(organization_id: organization.to_param)
    wait_for_stimulus("org--invite-form")

    expect(page).to have_button("Send invitation", disabled: true)
    expect(page).to have_content("2 invitations remaining")

    fill_in "multiple_emails_invited", with: "first@example.com, not-an-email"
    expect(page).to have_content("Not a valid email: not-an-email")
    expect(page).to have_content("1 email")
    expect(page).to have_button("Send invitation", disabled: true)

    fill_in "multiple_emails_invited", with: "Name <first@example.com>"
    expect(page).to have_content("Not a valid email: Name, <first@example.com>")
    fill_in "multiple_emails_invited", with: "first@example.com."
    expect(page).to have_content("Not a valid email: first@example.com.")
    # The message hides once the email is fixed, and has to come back for the next mistake
    fill_in "multiple_emails_invited", with: "first@example.com"
    expect(page).to have_no_content("Not a valid email")
    fill_in "multiple_emails_invited", with: "first@example.com, oops"
    expect(page).to have_content("Not a valid email: oops")

    fill_in "multiple_emails_invited", with: "first@example.com FIRST@example.com"
    expect(page).to have_content("1 email")
    expect(page).to have_button("Send invitation", disabled: false)

    fill_in "multiple_emails_invited", with: "first@example.com\nsecond@example.com\nthird@example.com"
    expect(page).to have_content("You only have 2 invitations left.")
    expect(page).to have_button("Send 3 invitations", disabled: true)

    fill_in "multiple_emails_invited", with: "first@example.com second@example.com first@example.com"
    expect(page).to have_content("2 emails")
    choose "organization_role_role_member_no_bike_edit"
    expect {
      click_button "Send 2 invitations"
      expect(page).to have_content("2 users invited")
    }
      .to change(OrganizationRole, :count).by 2
    expect(organization.organization_roles.where(invited_email: %w[first@example.com second@example.com]).pluck(:role).uniq)
      .to eq(["member_no_bike_edit"])
  end

  describe "updating a role" do
    let(:organization_role) { FactoryBot.create(:organization_role_claimed, organization:, role: "member") }

    it "enables the update once the role changes" do
      visit edit_organization_user_path(organization_role.id, organization_id: organization.to_param)
      wait_for_stimulus("org--role-form")

      expect(page).to have_button("Update role", disabled: true)
      choose "organization_role_role_admin"
      expect(page).to have_button("Update role", disabled: false)
      choose "organization_role_role_member"
      expect(page).to have_button("Update role", disabled: true)

      choose "organization_role_role_admin"
      click_button "Update role"
      expect(page).to have_content("Updated membership")
      expect(organization_role.reload.role).to eq "admin"
    end
  end
end
