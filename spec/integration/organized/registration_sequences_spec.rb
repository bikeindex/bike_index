# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized registration sequences", :js, type: :system do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[registration_sequences registration_sequences_edit])
  end
  let(:user) { FactoryBot.create(:organization_admin, organization:) }

  before do
    # Org drafts are cloned from the global template seeded here
    load Rails.root.join("db/seeds/seed_registration_sequence_template.rb").to_s
    sign_in(user)
  end

  it "builds a draft from the template, then edits a page and the sequence" do
    visit "/o/#{organization.to_param}/registration_sequences"

    # Build the draft (cloned from the seeded template) and open the management view
    click_button "Create a sequence"
    expect(page).to have_content("Draft registration sequence")
    expect(page).to have_content("Batteries & charging") # cloned from the template

    # --- Edit the sequence: add a page. Done before the page edit so the success flash from a
    # save isn't covering the "+ Add page" header link. ---
    click_link "Add page"
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10) # editors upgrade lazily
    fill_in "Title", with: "Winter storage rules"
    # A page needs at least one rule to save
    new_bullet = first("lexxy-editor [contenteditable='true']")
    new_bullet.click
    new_bullet.send_keys("Drain the battery before storing")
    click_button "Add page"

    expect(page).to have_content("Winter storage rules")

    # --- Edit a page: it previews as registrants see it, and editing marks it stale ---
    click_link "Edit", match: :first
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)
    expect(page).to have_content("Preview") # the saved page shows below the form

    # Ticking a preview checkbox isn't a form edit, so the preview stays put
    within("[data-page-preview-target='preview']") { first("input[type=checkbox]").click }
    expect(page).to have_no_content("Save the page to see the updated preview")

    fill_in "Title", with: "Battery safety pledge"
    # Editing hides the now-stale preview and asks for a save
    expect(page).to have_content("Save the page to see the updated preview")

    fill_in "Subtitle", with: "Charge safely on campus"

    bullet = first("lexxy-editor [contenteditable='true']")
    bullet.click
    bullet.send_keys(" reviewed 2026")

    attach_file "registration_sequence_page[image]",
      Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true
    # the UI::Forms::FileUpload Stimulus controller reflects the chosen file
    expect(page).to have_css("[data-ui--forms--file-upload-target='filename']", text: "bike.jpg")

    click_button "Save page"

    # Saving returns to this page with its preview refreshed to the new content
    expect(page).to have_content("Preview")
    expect(page).to have_content("Charge safely on campus") # the new subtitle, shown in the preview

    # Persistence
    draft = organization.registration_sequences.draft.first
    edited = draft.registration_sequence_pages.find_by(title: "Battery safety pledge")
    expect(edited.subtitle).to eq "Charge safely on campus"
    expect(edited.body).to include("reviewed 2026")
    expect(edited.image).to be_attached
    expect(draft.registration_sequence_pages.pluck(:title)).to include("Campus-specific rules")
  end

  it "gates each preview page on its rules like the real flow, then finishes to editing" do
    visit "/o/#{organization.to_param}/registration_sequences"
    click_button "Create a sequence"

    click_link "Preview"
    # Continue is disabled until every rule is checked - the same register--acknowledgment
    # controller the real flow uses
    expect(page).to have_button("Continue", disabled: true)

    loop do
      all("input[type=checkbox]").each { |box| box.click unless box.checked? }
      break unless page.has_button?("Continue", wait: 2)
      click_button "Continue"
    end

    expect(page).to have_content("almost done") # the review screen
    click_button "Finish preview"

    expect(page).to have_content("Draft registration sequence") # back in the editor
  end

  # Drives the bullet-editors Stimulus controller end-to-end (add a row, clone the <template>,
  # upgrade a fresh Lexxy editor). This can't catch the importmap relative-import 404 that broke
  # this in production -- dev and test serve undigested assets, so a relative import resolves here
  # too. That specific regression is guarded by spec/javascript_controller_imports_spec.rb.
  it "adds a bullet to a page that already has bullets" do
    visit "/o/#{organization.to_param}/registration_sequences"
    click_button "Create a sequence"
    click_link "Edit", match: :first
    expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10) # editors upgrade lazily

    initial = all("[data-bullet-editors-target='item']", visible: :all).count
    expect(initial).to be > 1 # the cloned template page ships several bullets

    click_button "+ Add bullet"

    # Fails if the bullet-editors controller never wired up its add action
    expect(page).to have_css("[data-bullet-editors-target='item']", count: initial + 1, visible: :all, wait: 8)
    # the new row's editor must upgrade into a usable Lexxy editor, not an inert element
    expect(page).to have_css("lexxy-editor lexxy-toolbar", count: initial + 1, wait: 10)
  end
end
