# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::ColumnSettings::Component, :js, type: :system do
  it "picks the export form's columns with all, none and default, storing nothing" do
    visit "/rails/view_components/pages/org/search/column_settings/component/export_form"

    expect(page).to have_text("Included columns")
    expect(page).to have_checked_field("export_headers_registered_at")
    expect_axe_clean

    click_button "none"
    expect(page).to have_no_css("input[name='export[headers][]']:checked")

    click_button "default"
    expect(page).to have_checked_field("export_headers_registered_at")
    expect(page).to have_unchecked_field("export_headers_link")

    click_button "all"
    expect(page).to have_no_css("input[name='export[headers][]']:not(:checked)")
    expect(page.evaluate_script("localStorage.length")).to eq 0
  end
end
