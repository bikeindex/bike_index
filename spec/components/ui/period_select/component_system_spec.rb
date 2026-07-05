# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::PeriodSelect::Component, :js, type: :system do
  context "when toggling the custom range with the collapse controller" do
    it "expands and collapses the custom form" do
      # The default preview renders with period: "all", so the custom form
      # starts collapsed (tw:hidden).
      visit "/rails/view_components/ui/period_select/component/default"

      # Collapsed (hidden), so the form's fields aren't visible.
      expect(page).to have_no_button("Update")

      click_button("custom")

      # collapse#show removes the hidden class and animates the form open.
      expect(page).to have_button("Update")
      expect(page).to have_field("From")
      expect(page).to have_field("To")

      click_button("custom")

      # collapse#hide animates it closed and re-adds the hidden class.
      expect(page).to have_no_button("Update")

      expect_axe_clean
    end
  end
end
