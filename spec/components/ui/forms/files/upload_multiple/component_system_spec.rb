# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Files::UploadMultiple::Component, :js, type: :system do
  let(:status) { "[data-ui--forms--files--picker-target='status']" }
  let(:fixture) { Rails.root.join("spec/fixtures/bike.jpg").to_s }
  # Dragging a file has no Capybara equivalent -- the drag source is the OS, not the
  # page -- so the events carry a hand-built DataTransfer, per Playwright's docs.
  let(:drop_two_files) do
    <<~JS
      const transfer = new DataTransfer()
      transfer.items.add(new File(["x"], "dropped.jpg", {type: "image/jpeg"}))
      transfer.items.add(new File(["y"], "second.jpg", {type: "image/jpeg"}))
      document.querySelector("[data-ui--forms--files--picker-target='list']")
        .dispatchEvent(new DragEvent("drop", {bubbles: true, dataTransfer: transfer}))
    JS
  end

  # Nothing answers the preview's url, so every pick ends in the failed state -- which is
  # what shows that each file is uploaded, and reported on, in a request of its own
  it "gives every picked or dropped file a row of its own, and says which ones didn't land" do
    visit("/rails/view_components/ui/forms/files/upload_multiple/component/default")

    expect(page).to have_css("[data-ui--forms--files--picker-target='list'] li", text: "already stored")
    expect(page).to have_no_css("#{status} li")
    expect_axe_clean

    attach_file("Upload", [fixture, Rails.root.join("spec/fixtures/exif_orientation.jpg").to_s],
      make_visible: true)

    expect(page).to have_css("#{status} li[data-failed='true']", text: "bike.jpg", wait: 10)
    expect(page).to have_css("#{status} li[data-failed='true']", text: "exif_orientation.jpg")
    expect(page).to have_css("#{status} li", text: "upload failed", count: 2)
    # the list is only added to by an upload that landed
    expect(page).to have_css("[data-ui--forms--files--picker-target='list'] li", count: 1)

    # onto the list, not the button: the whole component takes a drop, and both files of it
    page.execute_script(drop_two_files)

    expect(page).to have_css("#{status} li", text: "dropped.jpg", wait: 10)
    expect(page).to have_css("#{status} li", text: "second.jpg")
  end
end
