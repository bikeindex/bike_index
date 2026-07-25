# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, :js, type: :system do
  context "when interacting with the default dropdown" do
    it "opens and closes" do
      visit "/rails/view_components/ui/dropdown/component/default"

      expect(page).to have_css('[aria-expanded="false"]')
      expect_axe_clean

      click_button("Menu")

      expect(page).to have_css('[aria-expanded="true"]')
      expect(page).to have_text("Profile")
      expect(page).to have_text("Settings")
      expect(page).to have_text("Logout")
      expect(page).to have_css('li[role="menuitem"]:nth-child(2) + li[role="separator"] + li[role="menuitem"]')
      expect_axe_clean

      send_keys(:escape)

      expect(page).to have_css('[aria-expanded="false"]')

      click_button("Menu")

      expect(page).to have_css('[aria-expanded="true"]')

      page.find("body").click

      expect(page).to have_css('[aria-expanded="false"]')
    end
  end

  context "when interacting with the custom_button dropdown" do
    it "opens with header and items" do
      visit "/rails/view_components/ui/dropdown/component/custom_button"

      expect(page).to have_css('[aria-expanded="false"]')
      expect_axe_clean

      click_button("seth herr")

      expect(page).to have_css('[aria-expanded="true"]')
      expect(page).to have_text("Last synced: 2 minutes ago")
      expect(page).to have_text("Settings")
      expect(page).to have_text("Sync")
      # The active item is marked aria-current; inactive items are not
      expect(page).to have_css('li[role="menuitem"][aria-current]', text: "Sync")
      expect(page).to have_css('li[role="menuitem"]:not([aria-current])', text: "Settings")
      expect_axe_clean

      send_keys(:escape)

      expect(page).to have_css('[aria-expanded="false"]')
    end
  end
end
