# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::RegistrationSequence::PageForm::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/org/registration_sequence/page_form/component/default" }
  let(:preview_selector) { "[data-page-preview-target='preview']" }
  let(:stale_hint) { "Save the page to see the updated preview." }
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
  let!(:registration_sequence_page) do
    FactoryBot.create(:registration_sequence_page, registration_sequence:, title: "Batteries & charging",
      heading: "Looks like you have an e-vehicle!", subtitle: "A few campus safety rules",
      body: "<ul><li>Charge safely</li><li>Store safely</li></ul>")
  end

  # Every trigger starts from a preview that hasn't gone stale, and only a load has one
  def visit_form
    visit preview_path

    expect(page).to have_css("lexxy-editor lexxy-toolbar", count: 2, wait: 10) # editors upgrade lazily
    expect(page).to have_css(preview_selector)
    expect(page).to have_no_content(stale_hint)
  end

  def expect_stale_after
    visit_form
    yield

    expect(page).to have_content(stale_hint)
    expect(page).to have_no_css(preview_selector)
  end

  def first_bullet
    first("lexxy-editor [contenteditable='true']")
  end

  it "hides the preview as soon as the page is edited" do
    visit_form

    # The preview is the page as registrants see it
    expect(page).to have_content("Looks like you have an e-vehicle!")
    expect(page).to have_content("Charge safely")
    expect_axe_clean

    # The preview's own checkboxes are decorative, so ticking one isn't an edit
    within(preview_selector) { first("input[type=checkbox]").click }

    expect(page).to have_no_content(stale_hint)

    expect_stale_after { fill_in "Title", with: "Battery safety" }
    expect_stale_after { fill_in "Heading", with: "Battery safety on campus" }
    expect_stale_after { check "Specific to Brakebills" }

    expect_stale_after do
      bullet = first_bullet
      bullet.click
      bullet.send_keys(" reviewed 2026")
    end

    expect_stale_after { click_button "+ Add bullet" }
    expect_stale_after { click_button "Remove", match: :first }

    # Upward: dropping on the top half of the row below lands where it already is
    expect_stale_after do
      all("[data-bullet-editors-target='handle']").last
        .drag_to(all("[data-bullet-editors-target='item']").first)

      expect(first_bullet).to have_text("Store safely")
    end

    # A new bullet row is new markup to audit
    click_button "+ Add bullet"
    expect(page).to have_css("lexxy-editor", count: 3, wait: 10)
    expect_axe_clean
  end
end
