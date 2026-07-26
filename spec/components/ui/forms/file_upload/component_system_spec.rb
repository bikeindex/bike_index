# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::FileUpload::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/file_upload/component/" }

  context "default" do
    it "shows the selected filename, and only offers Take picture on a coarse pointer" do
      visit("#{base_path}default")

      expect(page).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")

      attach_file("file", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)

      expect(page).to have_css("[data-form--file-upload-target='filename']", text: "bike.jpg")
      expect(page).to have_no_button("Take picture")

      emulate_touch_device

      click_on "Take picture"

      expect(page).to have_css("input[type='file'][capture='environment']", visible: :all)

      find("label", text: "Choose file").click

      expect(page).to have_no_css("input[type='file'][capture]", visible: :all)
    end
  end
end
