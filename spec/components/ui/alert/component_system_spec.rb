# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Alert::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/alert/component/#{kind}" }

  context "dismissable_error" do
    let(:kind) { "dismissable_error" }

    it "is dismissable" do
      visit(preview_path)

      expect(page).to have_content "Dismissable error"
      expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

      find('button[aria-label="Close"]').click

      expect(page).to_not have_content "Dismissable error"
    end
  end
end
