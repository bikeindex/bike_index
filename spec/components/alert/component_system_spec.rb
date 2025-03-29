# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alert::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/alert/component/#{kind}" }

  context "dismissable_error" do
    let(:kind) { "dismissable_error" }

    it "is dismissable" do
      visit(preview_path)

      expect(page).to have_content "A simple alert with some info"

      find('button[aria-label="Close"]').click

      expect(page).to_not have_content "a simple alert with some info"
    end
  end
end
