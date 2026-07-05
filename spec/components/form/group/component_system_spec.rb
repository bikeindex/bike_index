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

  context "content_block" do
    it "focuses the paired Lexxy editor when the label is clicked" do
      visit("#{base_path}content_block")

      # Lexxy upgrades the <lexxy-editor> asynchronously -- wait for the toolbar before interacting.
      expect(page).to have_css("lexxy-editor lexxy-toolbar", wait: 10)

      find("label", text: "Description").click

      # the label click moves the caret into Lexxy's contenteditable box
      expect(page).to have_css("#organization_feature_description-content:focus")
    end
  end
end
