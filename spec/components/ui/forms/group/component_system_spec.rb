# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Group::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/group/component/" }

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
