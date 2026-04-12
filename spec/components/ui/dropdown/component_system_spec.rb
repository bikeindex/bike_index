# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, :js, type: :system do
  context "when interacting with the default dropdown" do
    it "opens and closes" do
      visit "/rails/view_components/ui/dropdown/component/default"

      expect(page).to have_css('[aria-expanded="false"]')
      expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

      click_button("Menu ▾")

      expect(page).to have_css('[aria-expanded="true"]')
      expect(page).to have_text("Profile")
      expect(page).to have_text("Settings")
      expect(page).to have_text("Logout")
      expect(page).to have_css('li[role="menuitem"]:nth-child(2) + li[role="separator"] + li[role="menuitem"]')
      expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

      send_keys(:escape)

      expect(page).to have_css('[aria-expanded="false"]')

      click_button("Menu ▾")

      expect(page).to have_css('[aria-expanded="true"]')

      page.find("body").click

      expect(page).to have_css('[aria-expanded="false"]')
    end
  end

  context "when interacting with the custom_button dropdown" do
    it "opens with header and items" do
      visit "/rails/view_components/ui/dropdown/component/custom_button"

      expect(page).to have_css('[aria-expanded="false"]')
      expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

      click_button("seth herr ▾")

      expect(page).to have_css('[aria-expanded="true"]')
      expect(page).to have_text("Last synced: 2 minutes ago")
      expect(page).to have_text("Settings")
      expect(page).to have_text("Sync")
      expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

      send_keys(:escape)

      expect(page).to have_css('[aria-expanded="false"]')
    end
  end
end
