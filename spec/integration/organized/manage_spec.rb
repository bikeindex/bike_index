# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized manage", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }

  before do
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "shows the chosen filename in the organization logo field" do
    visit "/o/#{organization.to_param}/manage"

    expect(page).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")

    attach_file("organization[avatar]", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)

    expect(page).to have_css("[data-form--file-upload-target='filename']", text: "bike.jpg")
  end
end
