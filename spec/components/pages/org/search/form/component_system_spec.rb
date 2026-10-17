# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::Form::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/org/search/form/component/default" }

  describe "default preview" do
    it "renders the search form, and submits it" do
      visit(preview_path)

      expect(page).to have_css("form#Search_Form")
      expect_axe_clean
      expect(page).to have_field("search_email")
      expect(page).to have_field("serial")

      fill_in "search_email", with: "test@example.com"
      fill_in "serial", with: "ABC123"

      find("button[type='submit']").click

      expect(page).to have_current_path(/search_email=test/, wait: 5)
    end
  end

  describe "with_filters preview" do
    let(:preview_path) { "/rails/view_components/pages/org/search/form/component/with_filters" }
    let!(:organization) { FactoryBot.create(:organization_brakebills) }
    let(:panel) { "[data-ui--collapse-target='content']" }

    it "opens the search settings from the gear, and keeps it open across a reload" do
      visit(preview_path)
      expect(page).to have_css("form#Search_Form", wait: 5)
      page.execute_script("localStorage.removeItem('orgRegistrationFiltersOpen')")
      visit(preview_path)

      expect(page).not_to have_css(panel, visible: true, wait: 2)

      click_button "Search settings and filters"
      expect(page).to have_css(panel, visible: true, wait: 5)
      expect(page).to have_text("Status:")

      page.refresh
      expect(page).to have_css(panel, visible: true, wait: 5)

      click_button "Search settings and filters"
      expect(page).not_to have_css(panel, visible: true, wait: 5)
    end
  end

  describe "searching_all_registrations preview" do
    let(:preview_path) { "/rails/view_components/pages/org/search/form/component/searching_all_registrations" }
    let!(:organization) { FactoryBot.create(:organization_brakebills) }

    it "folds away the owner email while searching all, and shows it again when unchecked" do
      visit(preview_path)

      expect(page).to have_field("serial", with: "ABC123")
      expect(page).to have_checked_field("search_all")
      expect(page).not_to have_field("search_email", wait: 2)

      uncheck "search_all"
      expect(page).to have_field("search_email", wait: 5)
    end
  end
end
