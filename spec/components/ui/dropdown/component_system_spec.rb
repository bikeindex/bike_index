# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, :js, type: :system do
  context "when interacting with the dropdown" do
    it "opens and closes" do
      visit "/rails/view_components/ui/dropdown/component/default"

      expect(page).to have_css('[aria-expanded="false"]')

      click_button("Menu ▼")

      expect(page).to have_css('[aria-expanded="true"]')
      expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

      send_keys(:escape)

      expect(page).to have_css('[aria-expanded="false"]')
    end
  end
end
