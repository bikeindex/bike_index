# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized registration sequences", :js, type: :system do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["registration_sequences"])
  end
  let(:user) { FactoryBot.create(:organization_admin, organization:) }

  before do
    # Org drafts are cloned from the global template seeded here
    load Rails.root.join("db/seeds/seed_registration_sequence_template.rb").to_s
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "builds a draft from the template, then edits a page and the sequence" do
    visit "/o/#{organization.to_param}/registration_sequences"

    # Build the draft (cloned from the seeded template) and open the management view
    click_button "Edit sequence"
    expect(page).to have_content("Draft registration sequence")
    expect(page).to have_content("Battery & charging") # cloned from the template

    # --- Edit the sequence: add a page. Done before the page edit so the success flash from a
    # save isn't covering the "+ Add page" header button. ---
    click_button "Add page"
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10) # editors upgrade lazily
    fill_in "Title", with: "Campus-specific rules"
    click_button "Save page"

    expect(page).to have_content("Campus-specific rules")

    # --- Edit a page: title, subtitle, a bullet, and the image ---
    click_link "Edit", match: :first
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)

    fill_in "Title", with: "Battery safety pledge"
    fill_in "Subtitle", with: "Charge safely on campus"

    bullet = first("lexxy-editor [contenteditable='true']")
    bullet.click
    bullet.send_keys(" reviewed 2026")

    attach_file "registration_sequence_page[image]",
      Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true
    # the Form::FileUpload Stimulus controller reflects the chosen file
    expect(page).to have_css("[data-form--file-upload-target='filename']", text: "bike.jpg")

    click_button "Save page"

    # Back on the management view, the edited title shows and the old one is gone
    expect(page).to have_content("Battery safety pledge")
    expect(page).to have_no_content("Battery & charging")

    # Persistence
    draft = organization.registration_sequences.draft.first
    edited = draft.registration_sequence_pages.find_by(title: "Battery safety pledge")
    expect(edited.subtitle).to eq "Charge safely on campus"
    expect(edited.body).to include("reviewed 2026")
    expect(edited.image).to be_attached
    expect(draft.registration_sequence_pages.pluck(:title)).to include("Campus-specific rules")
  end
end
