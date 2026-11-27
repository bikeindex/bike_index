# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Group::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/group/component/" }

  # The group labels the input and UI::Forms::Files::Upload's visible button is a label for the same input,
  # so this is what would catch axe's form-field-multiple-labels
  context "file_upload" do
    it "audits clean with the upload control nested in the group" do
      visit("#{base_path}file_upload")

      expect(page).to have_css("label", text: "Avatar")
      expect(page).to have_css("label", text: "Upload")
      expect_axe_clean
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

  # The browser's bubble isn't in the page, so what it says is read off the field
  context "validated" do
    def validation_message(name) = evaluate_script("document.querySelector('[name=\"#{name}\"]').validationMessage")

    it "says what each format wants, and lets a corrected value through" do
      visit("#{base_path}validated")
      wait_for_stimulus("ui--forms--format-message")

      click_on "Submit"
      expect(validation_message("validated[phone]")).to eq "Enter a phone number with at least 7 digits, like 503 555 0123"

      fill_in "Phone", with: "503 555 0123"
      click_on "Submit"
      expect(validation_message("validated[phone]")).to eq ""
      expect(validation_message("validated[website]")).to eq "Enter a website, like example.com"

      fill_in "Website", with: "example.com"
      click_on "Submit"
      expect(validation_message("validated[postal_code]")).to start_with "Enter a postal code"
      expect(validation_message("validated[address_record][postal_code]")).to start_with "Enter a postal code"
    end
  end
end
