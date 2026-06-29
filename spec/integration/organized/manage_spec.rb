# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized manage", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization, name: "Old name", website: nil) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  # An existing location keeps the manage form from rendering the required new-location sub-form
  let!(:location) { FactoryBot.create(:location, organization:) }

  before do
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "updates organization fields and attaches the logo" do
    visit "/o/#{organization.to_param}/manage"

    fill_in "Name", with: "New name"
    fill_in "Website", with: "https://example.com"
    check "Send emails directly to unclaimed bike owners."

    expect(page).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")
    attach_file("organization[avatar]", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)
    # the Form::FileUpload Stimulus controller reflects the chosen file in the field
    expect(page).to have_css("[data-form--file-upload-target='filename']", text: "bike.jpg")

    within("form.organized-form") { click_button "Update" }

    expect(page).to have_content("updated successfully")

    organization.reload
    expect(organization.name).to eq "New name"
    expect(organization.website).to eq "https://example.com"
    expect(organization.direct_unclaimed_notifications).to be true
    expect(organization.avatar?).to be_truthy
    expect(organization.avatar_identifier).to eq "bike.jpg"
  end
end
