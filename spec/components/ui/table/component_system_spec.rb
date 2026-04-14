# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Table::Component, :js, type: :system do
  it "sortable_with_cache is axe clean" do
    visit("/rails/view_components/ui/table/component/sortable_with_cache")

    expect(page).to have_css("table")
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
  end
end
