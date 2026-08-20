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
      # ui--active-link marks the link that points at this page, and .twdropdown fills it
      expect(page).to have_css('li[role="menuitem"] a[aria-current]', text: "Sync (active)")
      expect(page).to have_no_css('li[role="menuitem"] a[aria-current]', text: "Settings")
      expect(page.evaluate_script(<<~JS)).to eq "rgb(255, 255, 255)"
        getComputedStyle(document.querySelector('li[role="menuitem"] a[aria-current]')).color
      JS
      expect_axe_clean

      send_keys(:escape)

      expect(page).to have_css('[aria-expanded="false"]')
    end
  end

  context "when the widest entry is wider than the button" do
    it "widens the menu to fit it on one line, without exceeding the viewport" do
      visit "/rails/view_components/ui/dropdown/component/long_entry"
      click_button("Mail")

      expect(page).to have_css('[aria-expanded="true"]')

      metrics = page.evaluate_script(<<~JS)
        (() => {
          const menu = document.querySelector('[data-ui--dropdown-target="menu"]');
          const entry = [...menu.querySelectorAll('li[role="menuitem"] a')]
            .find(a => a.textContent.includes('Letter opener'));
          const style = getComputedStyle(entry);
          const padding = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom);
          return {
            lines: Math.round((entry.getBoundingClientRect().height - padding) / parseFloat(style.lineHeight)),
            menuWidth: menu.getBoundingClientRect().width,
            buttonWidth: document.querySelector('[data-ui--dropdown-target="button"]').getBoundingClientRect().width,
            maxWidth: window.innerWidth * 0.75
          };
        })()
      JS

      expect(metrics["lines"]).to eq 1
      expect(metrics["menuWidth"]).to be > metrics["buttonWidth"]
      expect(metrics["menuWidth"]).to be <= metrics["maxWidth"]
    end
  end
end
