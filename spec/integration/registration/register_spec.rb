# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Register flow", :js, type: :system do
  let(:owner_email) { "owner@bikeindex.org" }
  let(:user_name) { "Sally Rider" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }
  let!(:blue) { FactoryBot.create(:color, name: "Blue") }
  let!(:green) { FactoryBot.create(:color, name: "Green") }

  before do
    # The manufacturer combobox autocompletes against the redis index
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_current_path("/my_account", wait: 5)
  end

  # Through step 1 and onto step 2, the way a rider gets there
  def start_registration
    visit "/register/new"

    # new creates the registration and lands on its tokenized step 1
    expect(page).to have_current_path(/register\?b_param_token=.+&step=1/, url: true)

    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    expect(page).to have_content("Add your bike")
  end

  # The emailed link, minus the mailer's host - the app under test is on Capybara's
  def confirmation_link
    Email::PartialRegistrationJob.drain
    url = ActionMailer::Base.deliveries.last.html_part.decoded[%r{https?://[^"]*/register/confirm[^"]*}]
    URI.parse(CGI.unescapeHTML(url)).request_uri
  end

  it "starts a registration, keeps a full details draft across a reload, and completes" do
    ActionMailer::Base.deliveries = []
    visit "/register/new"

    # new creates the registration and lands on its tokenized step 1
    expect(page).to have_current_path(/register\?b_param_token=.+&step=1/, url: true)

    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    expect(page).to have_content("Add your bike")
    details_url = page.current_url
    expect(details_url).to match(/register\?b_param_token=.+&step=2/)

    # The browser back button returns to step 1 on the same registration, prefilled
    page.go_back
    expect(page).to have_field("b_param_manufacturer_id", with: "Surly")
    expect(page).to have_field("b_param[owner_email]", with: owner_email)

    # Coming back from step 2 offers starting over - dismissing keeps the registration
    open_modal(find_button("Start over"))
    find("#start-over-modal [aria-label='Close']").click
    click_button "Next"
    expect(page).to have_current_path(details_url, url: true)

    # Confirming swaps it for a blank registration, which has nothing to start over from
    click_link "Back"
    open_modal(find_button("Start over"))
    click_link "Yes, start over"
    expect(page).to have_field("b_param[owner_email]", with: "")
    expect(page).to have_no_button("Start over")

    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"
    expect(page).to have_content("Add your bike")
    details_url = page.current_url

    # Fill every field: text, chip radio, unit select, comboboxes (including the
    # collapsed additional-color rows) and the missing-serial checkbox
    fill_in "bike[user_name]", with: user_name
    fill_in "bike[frame_model]", with: "Marlin 7"
    fill_in "bike[year]", with: "2023"
    type_into("#bike_primary_frame_color_id", "Red")
    click_combobox_option("Red")
    click_button "+ Add another color"
    type_into("#bike_secondary_frame_color_id", "Blue")
    click_combobox_option("Blue")
    click_button "+ Add another color"
    type_into("#bike_tertiary_frame_color_id", "Green")
    click_combobox_option("Green")
    find("label", text: "M", exact_text: true).click
    select "cm", from: "bike[frame_size_unit]"
    check "Missing serial"
    # readonly rather than disabled, so "unknown" still submits
    expect(page).to have_field("bike[serial_number]", with: "unknown", readonly: true)
    fill_in "bike[bike_sticker]", with: "A 471 829"

    # Nothing submitted yet - the reload restores the whole draft from form-persist
    visit details_url

    expect(page).to have_field("bike[user_name]", with: user_name)
    expect(page).to have_field("bike[frame_model]", with: "Marlin 7")
    expect(page).to have_field("bike[year]", with: "2023")
    expect(page).to have_field("bike_primary_frame_color_id", with: "Red")
    expect(find("input[name='bike[primary_frame_color_id]']", visible: :all).value).to eq red.id.to_s
    # A restored selection repaints the rich_display overlay, so it keeps its swatch
    expect(page).to have_css("[data-ui--forms--combobox-display-target='overlay']", text: "Red")
    # The restored additional colors reveal their collapsed rows and use up the add button
    expect(page).to have_field("bike_secondary_frame_color_id", with: "Blue")
    expect(page).to have_field("bike_tertiary_frame_color_id", with: "Green")
    expect(page).to have_no_button("+ Add another color")
    expect(find("input[name='bike[frame_size]'][value='m']", visible: :all)).to be_checked
    # A select always has a value, so it restores from the draft rather than the server default
    expect(page).to have_select("bike[frame_size_unit]", selected: "cm")
    # The restored missing serial re-reveals the made-without link
    expect(page).to have_field("bike[serial_number]", with: "unknown", readonly: true)
    expect(page).to have_checked_field("Missing serial")
    expect(page).to have_button("This bike was made without a serial number")
    expect(page).to have_field("bike[bike_sticker]", with: "A 471 829")

    # The modal's made-without confirm mutates fields programmatically - that
    # state survives a reload too
    click_button "This bike was made without a serial number"
    click_button "I'm 100% sure"
    expect(page).to have_checked_field("This bike was made without a serial")

    visit details_url

    expect(page).to have_checked_field("This bike was made without a serial")
    expect(page).to have_no_field("bike[serial_number]") # the serial section stays swapped out

    # Like bikes/new, phone is only asked for once the status calls for it
    expect(page).to have_no_field("bike[phone]")
    type_into("#bike_status", "Stolen")
    click_combobox_option("Stolen")

    # The status the server renders is only a default, so the draft outlives a
    # reload - and the fields it gates reopen with it
    visit details_url

    expect(page).to have_field("bike_status", with: "Stolen")
    expect(find("input[name='bike[status]']", visible: :all).value).to eq "status_stolen"
    fill_in "bike[phone]", with: "(555) 000-0000"

    # Anonymous, so this uploads against the registration's token - after the reload above,
    # which would have dropped a file picked before it
    attach_file("bike_image", Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg"), make_visible: true)
    expect(page).to have_content("bike_photo-landscape.jpeg")
    expect(page).to have_no_content("uploading")

    click_button "Complete Bike Registration"

    # Anonymous, so there's nobody to own a bike yet - it's held for the emailed link
    expect(page).to have_content("Registration saved")
    expect(page).to have_content("verify your email")
    expect(Bike.count).to eq 0
    b_param = BParam.last
    expect(b_param.bike).to include("user_name" => user_name, "frame_model" => "Marlin 7", "year" => "2023",
      "primary_frame_color_id" => red.id.to_s, "secondary_frame_color_id" => blue.id.to_s,
      "tertiary_frame_color_id" => green.id.to_s, "frame_size" => "m",
      "serial_number" => "made_without_serial", "phone" => "(555) 000-0000",
      "status" => "status_stolen")
    expect(BikeServices::Register.send(:details_completed?, b_param)).to be_truthy
    expect(ActiveStorage::Blob.find_signed!(b_param.image_signed_id).filename.to_s)
      .to eq "bike_photo-landscape.jpeg"

    # The emailed link lands on the interstitial, which waits for a click
    visit confirmation_link
    click_button "Continue"

    expect(page).to have_content("Registration complete", wait: 10)
    bike = Bike.last
    expect(bike).to have_attributes(owner_email:, serial_number: "made_without_serial",
      status: "status_stolen", frame_model: "Marlin 7")
    # Signed in as the account the link made - to anyone else it reads as unclaimed
    expect(page).to have_content("keep watch")

    # An account nobody signed up for, so the terms are the first thing it's asked
    visit "/my_account"
    check "user_terms_of_service"
    click_button "Submit"

    expect(page).to have_current_path("/my_account", wait: 5)
    user = User.last
    expect(user).to have_attributes(email: owner_email, confirmed: true, terms_of_service: true)
    expect(bike.creator_id).to eq user.id
  end

  describe "signed in" do
    let(:current_user) { FactoryBot.create(:user_confirmed, email: owner_email) }
    let(:friend_email) { "friend@bikeindex.org" }

    before { sign_in(current_user) }

    it "asks for a name once the registration is going to someone other than them" do
      # Step 1 prefills their own address, which their account is already the name for
      start_registration
      expect(page).to have_no_field("bike[user_name]")

      # Sending it somewhere else is what asks - step 1 is where that's decided
      click_link "Back"
      fill_in "b_param[owner_email]", with: friend_email
      click_button "Next"
      expect(page).to have_field("bike[user_name]")

      type_into("#bike_primary_frame_color_id", "Red")
      click_combobox_option("Red")
      fill_in "bike[serial_number]", with: "GIFT1234"

      # Required, so the browser holds the submit without any js of ours
      click_button "Complete Bike Registration"
      expect(page).to have_current_path(/step=2/, url: true)
      expect(Bike.count).to eq 0

      fill_in "bike[user_name]", with: user_name
      click_button "Complete Bike Registration"

      expect(page).to have_content("Registration complete")
      # Their friend's registration to claim, not theirs
      expect(page).to have_content("We've emailed #{friend_email} so they can claim")
      expect(Bike.last).to have_attributes(owner_email: friend_email, owner_name: user_name)
    end
  end

  # The Disk service answers instantly, so what happens between picking a file and the blob
  # landing is only observable by holding the PUT open at the network layer.
  describe "an upload still in flight" do
    let(:image_path) { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }

    # Nothing in the handler answers the request, so it hangs the way a dead connection does
    def hang_the_upload
      page.driver.with_playwright_page do |playwright_page|
        playwright_page.route("**/rails/active_storage/disk/**", ->(_route, _request) {})
      end
    end

    def complete_the_registration
      type_into("#bike_primary_frame_color_id", "Red")
      click_combobox_option("Red")
      fill_in "bike[serial_number]", with: "HELD1234"
      fill_in "bike[user_name]", with: user_name # anonymous, so it's asked for
      click_button "Complete Bike Registration"
    end

    it "holds the submit until the blob lands, then sends it" do
      start_registration
      # Held just long enough to submit against it; the upload finishes on its own after
      page.driver.with_playwright_page do |playwright_page|
        playwright_page.route("**/rails/active_storage/disk/**", ->(route, _request) {
          sleep 3
          route.continue
        })
      end

      attach_file("bike_image", image_path, make_visible: true)
      expect(page).to have_content("uploading")

      complete_the_registration

      # Submitting doesn't navigate - the button spins while the upload finishes
      expect(page).to have_css("button[type='submit'][disabled]")
      expect(page).to have_current_path(/step=2/, url: true)

      # ...and once the blob lands the held submit goes through, carrying the photo
      expect(page).to have_content("Registration saved", wait: 15)
      expect(BParam.last.image_signed_id).to be_present
    end

    # Without this the button sits disabled behind a spinner until the page is reloaded
    it "gives up on an upload that stops responding, and submits without the photo" do
      start_registration
      hang_the_upload
      # Shortens the wait rather than skipping a step - the whole path still runs
      page.execute_script(<<~JS)
        document.querySelector("[data-controller~='ui--forms--file-upload']")
          .setAttribute("data-ui--forms--file-upload-stall-value", "1500")
      JS

      attach_file("bike_image", image_path, make_visible: true)

      expect(page).to have_content("upload failed", wait: 10)

      complete_the_registration

      expect(page).to have_content("Registration saved", wait: 15)
      expect(BParam.last.image_signed_id).to be_blank
    end
  end

  # The example above uploads to the Disk service, same-origin, which never exercises a presigned
  # S3 PUT or a cross-origin request. This one goes to the bikeindex-test R2 bucket for real, so
  # it needs credentials and the network. Kept separate so an R2 blip can't take the whole flow's
  # coverage with it - and signed in, because a bike (and so a PublicImage) is what has a url.
  describe "uploading to R2" do
    include_context :cloudflare_test_storage

    let(:image_path) { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }
    let(:current_user) { FactoryBot.create(:user_confirmed, email: owner_email) }

    before { sign_in(current_user) }

    it "PUTs the photo to the bucket and serves it from the storage domain" do
      start_registration

      # The field ships with its name so a JS-less submit posts the bytes; the controller
      # drops it on connect, which is what leaves the signed id as the only thing carrying
      # the photo. Both would otherwise arrive, and the b_param would hold two of them.
      expect(page).to have_no_css("input[name='bike[image]']", visible: :all)
      expect(page).to have_css("input#bike_image[type='file']", visible: :all)

      attach_file("bike_image", image_path, make_visible: true)
      expect(page).to have_content("bike_photo-landscape.jpeg")
      expect(page).to have_no_content("uploading", wait: 20) # A real cross-origin PUT

      # A color is required for the bike to save, and signed in it saves on submit
      type_into("#bike_primary_frame_color_id", "Red")
      click_combobox_option("Red")
      fill_in "bike[serial_number]", with: "R2UP1234"
      click_button "Complete Bike Registration"
      expect(page).to have_content("Registration complete")

      public_image = Bike.last.public_images.first
      expect(public_image.file.attached?).to be_truthy
      expect(public_image.image_url).to eq "https://test-uploads.bikeindex.org/#{public_image.file.blob.key}"

      # Fetching it is the actual proof the browser's PUT landed - and that the bucket serves it
      response = Faraday.get(public_image.image_url)
      expect(response.status).to eq 200
      expect(response.body.bytesize).to eq File.size(image_path)
    end
  end

  context "e-vehicle with an organization's safety rules" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    # Built as a draft and activated below, since activation freezes the pages
    let(:sequence) do
      FactoryBot.create(:registration_sequence, organization:,
        acknowledgment_text: "agree to comply with all of the rules above.")
    end
    let!(:battery_page) do
      FactoryBot.create(:registration_sequence_page, registration_sequence: sequence, listing_order: 0,
        title: "Battery & charging", subtitle: "Unsafe charging is the biggest cause of e-bike fires.",
        body: "<ul><li>Charge with the manufacturer's charger</li><li>Report a swollen battery</li></ul>")
    end
    let!(:campus_page) do
      FactoryBot.create(:registration_sequence_page, registration_sequence: sequence, listing_order: 1,
        title: "Campus rules", body: "<ul><li>Dismount in posted zones</li></ul>",
        organization_specific: true)
    end

    before { sequence.make_active! }

    it "gates each page of rules, then the acknowledgment, before completing" do
      visit "/register/new?organization_id=#{organization.slug}"

      type_into("#b_param_manufacturer_id", "Surly")
      click_combobox_option("Surly")
      check "Electric (motorized)"
      fill_in "b_param[owner_email]", with: owner_email
      click_button "Next"

      fill_in "bike[user_name]", with: user_name
      type_into("#bike_primary_frame_color_id", "Red")
      click_combobox_option("Red")
      fill_in "bike[serial_number]", with: "XYZ 123"
      # The safety pages come next, so step 2 no longer finishes the registration
      click_button "Next"

      expect(page).to have_content("Battery & charging")
      expect(page).to have_content("Electric (motorized) detected")
      expect(page).to have_content("E-Vehicle Acknowledgment · Step 1 of 3")
      expect(page).to have_button("Continue", disabled: true)

      check "Charge with the manufacturer's charger"
      expect(page).to have_button("Continue", disabled: true)
      check "Report a swollen battery"
      click_button "Continue"

      expect(page).to have_content("Campus rules")
      # The organization owns this page's rules, so they carry its name
      expect(page).to have_content("Brakebills")
      check "Dismount in posted zones"
      click_button "Continue"

      expect(page).to have_content("You're almost done")
      expect(page).to have_content("agree to comply with all of the rules above")
      expect(page).to have_button("Complete Bike Registration", disabled: true)

      # A page stays revisitable from the review, showing what was agreed to
      click_link "Review", match: :first
      expect(page).to have_content("Battery & charging")
      expect(page).to have_checked_field("Report a swollen battery")

      # Continuing walks forward through the remaining pages rather than jumping
      # straight back to the review
      click_button "Continue"
      expect(page).to have_content("Campus rules")
      click_button "Continue"

      expect(page).to have_content("You're almost done")
      # Registered for someone else, so it's their name that agrees
      check "I, #{user_name}, agree to comply with all of the rules above."
      click_button "Complete Bike Registration"

      expect(page).to have_content("Registration saved")
      acknowledgment = RegistrationSequenceAcknowledgment.last
      expect(acknowledgment).to have_attributes(registration_sequence_id: sequence.id,
        b_param_id: BParam.last.id, owner_email:,
        acknowledgment_text: "agree to comply with all of the rules above.")
      expect(acknowledgment.acknowledged_pages.pluck(:id)).to match_array([battery_page.id, campus_page.id])
    end

    # Every step submits through Turbo, which makes a throttle or a bad gateway a response
    # the page can retry - rather than an error page with the step's answers behind it.
    # This flow has one of every step, so each of them gets its turn at failing.
    context "when the server fails each step once" do
      let(:failed_steps) { [] }

      def step_param(url) = Rack::Utils.parse_query(URI.parse(url.to_s).query)["step"]

      # The first submission of each step is answered in the browser, the way an edge that
      # never reaches the app would; the retry that follows it is let through. The statuses
      # alternate so the throttle and the outright failure each get their turn.
      before do
        page.driver.with_playwright_page do |playwright_page|
          playwright_page.route(%r{/register}, ->(route, request) {
            # Every submission is a POST to one of three paths (Rails' method override), so
            # what tells the steps apart is the page each was submitted from
            step = [URI.parse(request.url).path, step_param(request.headers["referer"])]
            next route.continue if request.method == "GET" || failed_steps.include?(step)

            failed_steps << step
            route.fulfill(status: failed_steps.length.odd? ? 429 : 500,
              contentType: "text/plain", body: "Try again")
          })
        end
      end

      it "retries each of them, and the registration still finishes" do
        ActionMailer::Base.deliveries = []
        visit "/register/new?organization_id=#{organization.slug}"

        type_into("#b_param_manufacturer_id", "Surly")
        click_combobox_option("Surly")
        check "Electric (motorized)"
        fill_in "b_param[owner_email]", with: owner_email
        click_button "Next"

        # The failure is never something the rider sees - the retry is what lands
        expect(page).to have_content("Add your bike")

        fill_in "bike[user_name]", with: user_name
        type_into("#bike_primary_frame_color_id", "Red")
        click_combobox_option("Red")
        fill_in "bike[serial_number]", with: "XYZ 123"
        click_button "Next"

        expect(page).to have_content("Battery & charging")
        check "Charge with the manufacturer's charger"
        check "Report a swollen battery"
        click_button "Continue"

        expect(page).to have_content("Campus rules")
        check "Dismount in posted zones"
        click_button "Continue"

        expect(page).to have_content("You're almost done")
        check "I, #{user_name}, agree to comply with all of the rules above."
        click_button "Complete Bike Registration"

        expect(page).to have_content("Registration saved")

        # The emailed link finishes a step like any other, and fails like one
        visit confirmation_link
        click_button "Continue"

        expect(page).to have_content("Registration complete", wait: 10)
        expect(Bike.last).to have_attributes(owner_email:, serial_number: "XYZ 123",
          propulsion_type: "pedal-assist")
        # A retry that landed twice would show up as a second registration, or a second
        # signature on the rules
        expect(Bike.count).to eq 1
        expect(RegistrationSequenceAcknowledgment.count).to eq 1

        # Every step of the flow failed, and none of them more than once
        expect(failed_steps).to eq([["/register", "1"], ["/register", "2"],
          ["/register/acknowledge", "3"], ["/register/acknowledge", "4"],
          ["/register/acknowledge", "review"], ["/register/confirm_email", nil]])
      end
    end
  end
end
