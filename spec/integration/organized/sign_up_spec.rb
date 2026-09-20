# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized sign up", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
  let(:admin) { FactoryBot.create(:organization_admin, organization:) }
  let(:invited_email) { "newrider@brakebills.edu" }
  let(:organization_role) { organization.organization_roles.find_by(invited_email:) }

  it "invites a rider, who signs up, accepts the organization terms and lands in the organization" do
    sign_in(admin)
    visit "/o/#{organization.to_param}/users/new"

    fill_in "Email you're inviting", with: invited_email
    choose "Member of organization"

    expect { click_button "Send invitation" }
      .to change(UserJobs::ProcessOrganizationRoleJob.jobs, :count).by(1)
    expect(page).to have_content("#{invited_email} was invited to #{organization.name}")
    expect(organization_role.claimed?).to be_falsey

    expect { UserJobs::ProcessOrganizationRoleJob.drain }
      .to change(ActionMailer::Base.deliveries, :count).by(1)

    visit "/logout"
    # The rider takes the link out of the invitation
    visit emailed_path("/users/new")

    expect(find_field("Email").value).to eq invited_email
    fill_in "Name", with: "New Rider"
    check "user_terms_of_service"
    click_button "Sign up"

    # The invitation confirms them inline, so signing up signs them in and sends them to
    # the organization - which sends them straight back here until they accept its terms
    expect(page).to have_content("Please accept the terms of service for organizations", wait: 10)
    expect(page).to have_current_path("/accept_vendor_terms")

    rider = User.find_by(email: invited_email)
    expect(rider.confirmed?).to be_truthy
    expect(rider.accepted_vendor_terms_of_service?).to be_falsey

    # The organization sidebar covers the left of the viewport, so an agree bar laid out
    # against the viewport rather than the content column puts this checkbox behind it
    check "I agree to Bike Index's Terms of Service for Organizations."
    click_button "Submit"

    expect(page).to have_content("Now you can use Bike Index as #{organization.name}", wait: 10)
    expect(page).to have_current_path("/o/#{organization.to_param}/registrations", ignore_query: true)
    expect(rider.reload.accepted_vendor_terms_of_service?).to be_truthy
    expect(organization_role.reload.user_id).to eq rider.id
  end
end
