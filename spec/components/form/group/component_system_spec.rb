# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::Group::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/form/group/component/" }

  context "check_box" do
    it "toggles when label is clicked" do
      visit("#{base_path}check_box")

      checkbox_selector = "input[type='checkbox'][name='terms_of_service']"
      expect(page).to have_css checkbox_selector, visible: :all
      expect(page).not_to have_css "#{checkbox_selector}:checked", visible: :all

      find("label", text: "I agree to the terms of service").click
      expect(page).to have_css "#{checkbox_selector}:checked", visible: :all

      find("label", text: "I agree to the terms of service").click
      expect(page).not_to have_css "#{checkbox_selector}:checked", visible: :all
    end
  end
end
