# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::FileUpload::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/file_upload/component/" }
  let(:drop_frame) { "[data-ui--forms--file-upload-target='dropZone']" }
  let(:preview) { "[data-ui--forms--file-upload-target='preview']" }
  # Dragging a file has no Capybara equivalent -- the drag source is the OS, not the
  # page -- so the events carry a hand-built DataTransfer, per Playwright's docs.
  let(:start_drag) do
    <<~JS
      window.fileTransfer = new DataTransfer()
      window.fileTransfer.items.add(new File(["x"], "dropped.jpg", {type: "image/jpeg"}))
      document.dispatchEvent(new DragEvent("dragover", {bubbles: true, dataTransfer: window.fileTransfer}))
    JS
  end

  it "takes a file from the picker or a drag, and offers the camera only to a coarse pointer" do
    visit("#{base_path}default")

    expect(page).to have_css("[data-ui--forms--file-upload-target='filename']", text: "No file chosen")
    expect(page).to have_css("label", text: "Upload")
    # the frame is idle until something is dragged
    expect(page).to have_no_css("#{drop_frame}[data-dragging]")
    # nothing attached, so nothing to preview yet
    expect(page).to have_no_css(preview)

    attach_file("file", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)

    expect(page).to have_css("[data-ui--forms--file-upload-target='filename']", text: "bike.jpg")
    # the pick previews straight from the browser's copy, rather than waiting on an upload
    expect(page).to have_css("#{preview}[href^='blob:'] img[src^='blob:']")

    # dragging text rather than a file leaves the frame alone
    page.execute_script(<<~JS)
      const text = new DataTransfer()
      text.setData("text/plain", "not a file")
      document.dispatchEvent(new DragEvent("dragover", {bubbles: true, dataTransfer: text}))
    JS

    expect(page).to have_no_css("#{drop_frame}[data-dragging]")

    page.execute_script(start_drag)

    expect(page).to have_css("#{drop_frame}[data-dragging='true']")
    expect(page).to have_no_css("#{drop_frame}[data-over]")
    expect_axe_clean

    # the frame highlights under the cursor, and stays lit while crossing its own children
    page.execute_script(<<~JS)
      const frame = document.querySelector("#{drop_frame}")
      frame.dispatchEvent(new DragEvent("dragenter", {bubbles: true, dataTransfer: window.fileTransfer}))
      frame.dispatchEvent(new DragEvent("dragleave", {bubbles: true, relatedTarget: frame.querySelector("label")}))
    JS

    expect(page).to have_css("#{drop_frame}[data-over='true']")

    # leaving the window settles both states
    page.execute_script("document.dispatchEvent(new DragEvent('dragleave', {bubbles: true, relatedTarget: null}))")

    expect(page).to have_no_css("#{drop_frame}[data-dragging]")
    expect(page).to have_no_css("#{drop_frame}[data-over]")

    page.execute_script(start_drag)
    # onto the label, not the frame around it: the button says you can drop on it.
    # Two files into a single-file input -- only the first should land.
    page.execute_script(<<~JS)
      window.fileTransfer.items.add(new File(["y"], "second.jpg", {type: "image/jpeg"}))
      document.querySelector("[data-controller='ui--forms--file-upload'] label")
        .dispatchEvent(new DragEvent("drop", {bubbles: true, dataTransfer: window.fileTransfer}))
    JS

    expect(page).to have_css("[data-ui--forms--file-upload-target='filename']", text: "dropped.jpg")
    expect(page).to have_no_css("#{drop_frame}[data-dragging]")
    # those bytes aren't a jpeg whatever the name says -- the previous preview goes rather
    # than staying up as a broken image
    expect(page).to have_no_css(preview)
    # rendered, but the media query keeps it from a mouse
    expect(page).to have_button("Take picture", visible: :hidden)
    expect(page).to have_no_button("Take picture")

    # everything below runs touch-emulated -- fine-pointer assertions must come first
    emulate_touch_device

    # the camera button is only visible here, so this is the audit that covers it
    expect_axe_clean

    click_on "Take picture"

    expect(page).to have_css("input[type='file'][capture='environment']", visible: :all)

    find(:label, "Upload").click

    expect(page).to have_no_css("input[type='file'][capture]", visible: :all)
  end

  # This preview renders whatever the seeded org has attached, so it needs one
  context "with an image already attached" do
    let!(:organization) do
      FactoryBot.create(:organization_brakebills, avatar: File.open(Rails.root.join("spec/fixtures/bike.jpg")))
    end

    it "previews what's attached, rather than starting hidden as the empty picker does" do
      visit("#{base_path}with_existing_image")

      expect(page).to have_css("#{preview}[href*='bike.jpg'] img[src*='bike.jpg']")
      # Nothing picked this session, so the field still names no file
      expect(page).to have_css("[data-ui--forms--file-upload-target='filename']", text: "No file chosen")
      expect_axe_clean
    end
  end
end
