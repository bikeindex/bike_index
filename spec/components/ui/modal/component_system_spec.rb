# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Modal::Component, :js, type: :system do
  # Skip page-level rules that come from the component preview layout, not from the components
  let(:axe_skipped_rules) { [:"html-has-lang", :"landmark-one-main", :"page-has-heading-one", :region] }

  it "opens and closes modal" do
    visit("/rails/view_components/ui/modal/component/default")

    expect(page).to be_axe_clean.skipping(*axe_skipped_rules)

    click_button "Open Settings"

    expect(page).to have_text("Modal body content")

    find('button[aria-label="Close"]').click

    expect(page).not_to have_css("dialog[open]")
  end
end
