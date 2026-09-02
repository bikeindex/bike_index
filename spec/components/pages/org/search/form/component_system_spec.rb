# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::Form::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/org/search/form/component/default" }

  describe "default preview" do
    it "renders the search form" do
      visit(preview_path)

      expect(page).to have_css("form#Search_Form")
      expect_axe_clean
      expect(page).to have_field("search_email")
      expect(page).to have_field("serial")
    end

    it "submits the form" do
      visit(preview_path)

      fill_in "search_email", with: "test@example.com"
      fill_in "serial", with: "ABC123"

      find("button[type='submit']").click

      expect(page).to have_current_path(/search_email=test/, wait: 5)
    end
  end

  describe "without_serial_field preview" do
    let(:preview_path) { "/rails/view_components/pages/org/search/form/component/without_serial_field" }

    it "renders without serial field" do
      visit(preview_path)

      expect(page).to have_css("form#Search_Form")
      expect(page).to have_field("search_email")
      expect(page).not_to have_field("serial")
    end
  end

  describe "with_serial_value preview" do
    let(:preview_path) { "/rails/view_components/pages/org/search/form/component/with_serial_value" }

    it "renders with serial value prefilled" do
      visit(preview_path)

      expect(page).to have_field("serial", with: "ABC123")
    end
  end
end
