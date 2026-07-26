# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::FileUpload::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/file_upload/component/" }
  let(:drop_zone) { "[data-form--file-upload-target='dropZone']" }

  context "default" do
    it "takes a file from the picker or a drag, and only offers Take picture on a coarse pointer" do
      visit("#{base_path}default")

      expect(page).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")
      expect(page).to have_no_css(drop_zone)

      attach_file("file", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)

      expect(page).to have_css("[data-form--file-upload-target='filename']", text: "bike.jpg")

      # Dragging a file has no Capybara equivalent -- the drag source is the OS, not
      # the page -- so the events carry a hand-built DataTransfer, per Playwright's docs.
      page.execute_script(<<~JS)
        window.fileTransfer = new DataTransfer()
        window.fileTransfer.items.add(new File(["x"], "dropped.jpg", {type: "image/jpeg"}))
        document.dispatchEvent(new DragEvent("dragover", {bubbles: true, dataTransfer: window.fileTransfer}))
      JS

      expect(page).to have_css(drop_zone, text: "Drop a file here")

      page.execute_script(<<~JS)
        document.querySelector("#{drop_zone}")
          .dispatchEvent(new DragEvent("drop", {bubbles: true, dataTransfer: window.fileTransfer}))
      JS

      expect(page).to have_css("[data-form--file-upload-target='filename']", text: "dropped.jpg")
      expect(page).to have_no_css(drop_zone)
      expect(page).to have_no_button("Take picture")

      emulate_touch_device

      click_on "Take picture"

      expect(page).to have_css("input[type='file'][capture='environment']", visible: :all)

      find("label", text: "Choose file").click

      expect(page).to have_no_css("input[type='file'][capture]", visible: :all)
    end
  end
end
