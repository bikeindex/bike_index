# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organization embed registration", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_auto_user) }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:black) { Color.black }
  let(:owner_email) { "embedded@example.com" }

  before do
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  def fill_in_the_registration
    # Manufacturer loads its options over AJAX, hence the longer wait than the colors,
    # which are in the page already
    pick_remote_selectize(selectize_for("#bike_manufacturer_id"), "Surly")
    pick_selectize("#bike_primary_frame_color_id", "Black")

    fill_in "bike[serial_number]", with: "EMBED1234"
    fill_in "bike[owner_email]", with: owner_email
  end

  # Hold the blob's PUT open until the example releases it, so the submit is guaranteed to
  # land mid-upload. A timed delay would let a slow form fill outrun it, and the example
  # would still pass while testing nothing.
  def hold_the_upload
    held = Queue.new
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.route("**/rails/active_storage/disk/**", ->(route, _request) {
        # Pushing the token back leaves the gate open, so a later request doesn't
        # hang on the drained queue
        held.push(held.pop)
        route.continue
      })
    end
    -> { held.push(:release) }
  end

  # This form submits itself from its own handler rather than from the click, so an upload
  # still in flight is what proves the two work together
  it "uploads the photo straight to storage, holding the submit until the blob lands" do
    visit "/organizations/#{organization.slug}/embed"

    release_upload = hold_the_upload

    attach_file("bike_image", Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg"), make_visible: true)
    expect(page).to have_content("uploading")

    fill_in_the_registration
    click_button "Register"

    # The form's own handler is what would have submitted, and it says so when it does
    expect(page).to have_no_content("Please wait, processing")
    expect(page).to have_current_path("/organizations/#{organization.slug}/embed", ignore_query: true)

    # ...and once the blob lands the held submit goes through, carrying the photo
    release_upload.call
    expect(page).to have_content("has been added to Bike Index", wait: 15)
    bike = Bike.last
    expect(bike).to have_attributes(owner_email:, serial_number: "EMBED1234")
    expect(bike.current_ownership.organization&.id).to eq organization.id
    expect(ActiveStorage::Blob.find_signed!(BParam.last.image_signed_id).filename.to_s)
      .to eq "bike_photo-landscape.jpeg"
  end
end
