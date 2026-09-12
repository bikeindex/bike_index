# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::FileUploadMulti::Component, :js, type: :system do
  let(:drop_frame) { "[data-ui--forms--file-upload-multi-target='dropZone']" }
  let(:status) { "[data-ui--forms--file-upload-multi-target='status']" }
  let(:fixture) { Rails.root.join("spec/fixtures/bike.jpg").to_s }
  # Dragging a file has no Capybara equivalent -- the drag source is the OS, not the
  # page -- so the events carry a hand-built DataTransfer, per Playwright's docs.
  let(:start_drag) do
    <<~JS
      window.fileTransfer = new DataTransfer()
      window.fileTransfer.items.add(new File(["x"], "dropped.jpg", {type: "image/jpeg"}))
      document.dispatchEvent(new DragEvent("dragover", {bubbles: true, dataTransfer: window.fileTransfer}))
    JS
  end

  # Nothing answers the preview's url, so every pick ends in the failed state -- which is
  # what shows that each file is uploaded, and reported on, in a request of its own
  it "gives every picked or dropped file a row of its own, and says which ones didn't land" do
    visit("/rails/view_components/ui/forms/file_upload_multi/component/default")

    expect(page).to have_css("[data-ui--forms--file-upload-multi-target='list'] li", text: "already stored")
    expect(page).to have_no_css("#{status} li")
    # the frame is idle until something is dragged
    expect(page).to have_no_css("#{drop_frame}[data-dragging]")
    expect_axe_clean

    attach_file("Upload", [fixture, Rails.root.join("spec/fixtures/exif_orientation.jpg").to_s],
      make_visible: true)

    expect(page).to have_css("#{status} li[data-failed='true']", text: "bike.jpg", wait: 10)
    expect(page).to have_css("#{status} li[data-failed='true']", text: "exif_orientation.jpg")
    expect(page).to have_css("#{status} li", text: "upload failed", count: 2)
    # the list is only added to by an upload that landed
    expect(page).to have_css("[data-ui--forms--file-upload-multi-target='list'] li", count: 1)

    page.execute_script(start_drag)

    expect(page).to have_css("#{drop_frame}[data-dragging='true']")
    expect(page).to have_no_css("#{drop_frame}[data-over]")

    # the frame highlights under the cursor, and stays lit while crossing its own children
    page.execute_script(<<~JS)
      const frame = document.querySelector("#{drop_frame}")
      frame.dispatchEvent(new DragEvent("dragenter", {bubbles: true, dataTransfer: window.fileTransfer}))
      frame.dispatchEvent(new DragEvent("dragleave", {bubbles: true, relatedTarget: frame.querySelector("label")}))
    JS

    expect(page).to have_css("#{drop_frame}[data-over='true']")

    # onto the list, not the frame around the button: the whole component takes a drop.
    # Two files at once -- both land, unlike the single-file picker.
    page.execute_script(<<~JS)
      window.fileTransfer.items.add(new File(["y"], "second.jpg", {type: "image/jpeg"}))
      document.querySelector("[data-ui--forms--file-upload-multi-target='list']")
        .dispatchEvent(new DragEvent("drop", {bubbles: true, dataTransfer: window.fileTransfer}))
    JS

    expect(page).to have_css("#{status} li", text: "dropped.jpg", wait: 10)
    expect(page).to have_css("#{status} li", text: "second.jpg")
    # leaving the window settles both drag states
    expect(page).to have_no_css("#{drop_frame}[data-dragging]")
    expect(page).to have_no_css("#{drop_frame}[data-over]")
  end
end
