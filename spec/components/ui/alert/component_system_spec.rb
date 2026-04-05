# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Alert::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/alert/component/#{kind}" }
  # Skip page-level rules that come from the component preview layout, not from the components
  let(:axe_skipped_rules) { [:"html-has-lang", :"landmark-one-main", :"page-has-heading-one", :region] }

  context "dismissable_error" do
    let(:kind) { "dismissable_error" }

    it "is dismissable" do
      visit(preview_path)

      expect(page).to have_content "Dismissable error"
      expect(page).to be_axe_clean.skipping(*axe_skipped_rules)

      find('button[aria-label="Close"]').click

      expect(page).to_not have_content "Dismissable error"
    end
  end
end
