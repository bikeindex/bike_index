# frozen_string_literal: true

require "rails_helper"

# The flow's organization cases are in register_organized_spec.rb
RSpec.describe "Register flow", :js, type: :system do
  let(:owner_email) { "owner@bikeindex.org" }
  let(:user_name) { "Sally Rider" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }
  let!(:blue) { FactoryBot.create(:color, name: "Blue") }
  let!(:green) { FactoryBot.create(:color, name: "Green") }
  let!(:state) { FactoryBot.create(:state_new_york) }

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

  def submit_step_1
    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"
  end

  # fill_in focuses the field, then sends its text a round trip later - so a controller
  # connecting in between lands the text in the field filled just before
  def wait_for_details_step(wait: Capybara.default_max_wait_time)
    expect(page).to have_content("Add your bike", wait:)
    expect(page).to have_css("input[name='bike[frame_model]']:focus", wait:)
    wait_for_stimulus(timeout: wait)
  end

  # Answers every submission in the browser, the way an edge that never reaches the app
  # would, and collects what it turned away
  def fail_submissions(status:, headers: {})
    [].tap do |attempts|
      page.driver.with_playwright_page do |playwright_page|
        playwright_page.route(%r{/register}, ->(route, request) {
          next route.continue if request.method == "GET"

          attempts << request.url
          route.fulfill(status:, headers:, contentType: "text/plain", body: "Nope")
        })
      end
    end
  end

  # Through step 1 and onto step 2, the way a rider gets there
  def start_registration
    visit "/register/new"

    # new creates the registration and lands on its tokenized step 1
    expect(page).to have_current_path(/register\?b_param_token=.+&step=1/, url: true)

    submit_step_1

    wait_for_details_step
  end

  it "keeps a step 1 draft across a reload, and comes back to what it submitted" do
    visit "/register/new"
    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    type_into("#b_param_cycle_type", "e-Scooter")
    click_combobox_option("e-Scooter")
    fill_in "b_param[owner_email]", with: owner_email
    # An always-motorized type answers the electric question itself
    expect(page).to have_checked_field("Electric (motorized)", disabled: true)

    # Nothing is saved until step 1 submits, so the reload has only the draft to go on.
    # The restore runs in form-persist's connect, and its module is lazily loaded - so
    # the first assertion after a reload waits for the fetch, not just for a render
    visit page.current_url

    expect(page).to have_field("b_param_manufacturer_id", with: "Surly", wait: 10)
    expect(page).to have_field("b_param_cycle_type", with: "e-Scooter")
    expect(page).to have_field("b_param[owner_email]", with: owner_email)
    # The restored type reaches the section label and the electric checkbox, each of which
    # is a controller away from the combobox that changed
    expect(page).to have_content("E-SCOOTER INFO")
    expect(page).to have_checked_field("Electric (motorized)", disabled: true)

    click_button "Next"

    expect(page).to have_content("Add your e-scooter", wait: 10)
    # The draft is what submits, not just what showed
    expect(BParam.last).to have_attributes(manufacturer_id: manufacturer.id, owner_email:,
      cycle_type: "e-scooter", motorized?: true)

    # An async combobox carries no options to map a saved id back to a name, so the server
    # renders the display itself - and back to step 1 is where a raw id would show up instead
    page.go_back

    expect(page).to have_field("b_param_manufacturer_id", with: "Surly")
    # The id is what submits, and only ever from the hidden field
    expect(find("input[name='b_param[manufacturer_id]']", visible: :all).value).to eq manufacturer.id.to_s
    expect(page).to have_no_field("b_param_manufacturer_id", with: manufacturer.id.to_s)
    # The manufacturer itself, rather than Manufacturer.other with the id as free text
    expect(BParam.last.manufacturer_other).to be_blank

    # This field is autofocused, so the click into it brings no focus event of its own -
    # typing still replaces the restored name rather than mashing into the middle of it
    find_field("b_param_manufacturer_id").click
    send_keys("Kona")

    expect(page).to have_field("b_param_manufacturer_id", with: "Kona")
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

    wait_for_details_step
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
    wait_for_details_step
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
    # Hidden rather than removed, so "unknown" still submits
    expect(page).to have_no_field("bike[serial_number]")
    expect(page).to have_field("bike[serial_number]", with: "unknown", visible: :all)
    # No organization with stickers, and nothing scanned, so there is no sticker to give
    expect(page).to have_no_field("bike[bike_sticker]")

    # Unchecking has to undo the animated hide, not just its display:none
    uncheck "Missing serial"
    fill_in "bike[serial_number]", with: "SERIAL9"

    check "Missing serial"
    expect(page).to have_no_field("bike[serial_number]")

    # Nothing submitted yet - the reload restores the whole draft from form-persist
    visit details_url

    expect(page).to have_field("bike[user_name]", with: user_name, wait: 10)
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
    # The restored missing serial hides the input again and re-reveals the made-without link
    expect(page).to have_no_field("bike[serial_number]")
    expect(page).to have_field("bike[serial_number]", with: "unknown", visible: :all)
    expect(page).to have_checked_field("Missing serial")
    expect(page).to have_button("This bike was made without a serial number")

    # The modal's made-without confirm mutates fields programmatically - that
    # state survives a reload too
    click_button "This bike was made without a serial number"
    click_button "I'm 100% sure"
    expect(page).to have_checked_field("This bike was made without a serial")

    visit details_url

    expect(page).to have_checked_field("This bike was made without a serial", wait: 10)
    expect(page).to have_no_field("bike[serial_number]") # the serial section stays swapped out

    # The input was hidden twice getting here - by the missing checkbox, then by the
    # made-without swap - so unchecking has to bring it back from both
    uncheck "This bike was made without a serial"

    expect(page).to have_field("bike[serial_number]", with: "")
    expect(page).to have_unchecked_field("Missing serial")

    check "Missing serial"

    expect(page).to have_no_field("bike[serial_number]")

    click_button "This bike was made without a serial number"
    click_button "I'm 100% sure"

    expect(page).to have_checked_field("This bike was made without a serial")

    # Like bikes/new, phone is only asked for once the status calls for it
    expect(page).to have_no_field("bike[phone]")
    expect(page).to have_no_content("Phone is required")
    type_into("#bike_status", "Stolen")
    click_combobox_option("Stolen")

    # A theft is contacted on it, so the field it reveals asks rather than offers
    expect(page).to have_content("Phone is required to register a stolen bike")
    expect(find("input[name='bike[phone]']")[:required]).to be_present

    # The status the server renders is only a default, so the draft outlives a
    # reload - and the fields it gates reopen with it
    visit details_url

    expect(page).to have_field("bike_status", with: "Stolen", wait: 10)
    expect(find("input[name='bike[status]']", visible: :all).value).to eq "status_stolen"
    fill_in "bike[phone]", with: "(555) 000-0000"

    # Anonymous, so this uploads against the registration's token - after the reload above,
    # which would have dropped a file picked before it
    attach_file("bike_image", Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg"), make_visible: true)
    expect(page).to have_content("bike_photo-landscape.jpeg")
    expect(page).to have_no_content("uploading")

    # The theft is reported after this form, so the button doesn't claim to finish
    expect(page).to have_no_button("Complete Bike Registration")
    click_button "Next"

    # Anonymous, so there's nobody to own a bike yet - it's held for the emailed link
    expect(page).to have_css("h1", text: "Progress saved")
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

    # The emailed link lands on the interstitial, which waits for a click - confirming
    # proves the address, which leaves the theft it's reporting to tell us about
    visit confirmation_link
    click_button "Continue"

    expect(page).to have_content("Report your stolen bike", wait: 10)
    expect(Bike.count).to eq 0
    # When and where are required, and nothing was saved to fill them in from
    expect(page).to have_field("report[date]", with: "")
    fill_in "report[theft_description]", with: "Locked to a rack outside the coffee shop"
    fill_in "report[police_report_number]", with: "8675309"

    # Going back to fix a detail doesn't cost the report - the longest form in the flow,
    # and the one nothing has been saved from yet
    click_link "Back"
    expect(page).to have_content("Add your bike's details")
    click_button "Next"

    expect(page).to have_field("report[theft_description]",
      with: "Locked to a rack outside the coffee shop", wait: 10)
    expect(page).to have_field("report[police_report_number]", with: "8675309")

    # The browser holds the submit until when and where are answered, so nothing reaches
    # the server
    click_button "Complete Bike Registration"
    expect(page).to have_current_path(/step=report/, url: true)
    expect(Bike.count).to eq 0

    fill_in "report[date]", with: "2026-08-05T14:30"
    fill_in "report[address_record_attributes][street]", with: "278 Broadway"
    fill_in "report[address_record_attributes][city]", with: "New York"
    # The whole address is required alongside the street and city the server checks
    select state.name, from: "report[address_record_attributes][region_record_id]"
    fill_in "report[address_record_attributes][postal_code]", with: "10007"

    click_button "Complete Bike Registration"

    # The theft was the point of the flow, so the card heads with it rather than
    # congratulating them on a registration that's being watched over
    expect(page).to have_css("h1", text: "is listed as stolen on Bike Index", wait: 10)
    bike = Bike.last
    expect(bike).to have_attributes(owner_email:, serial_number: "made_without_serial",
      status: "status_stolen", frame_model: "Marlin 7")
    expect(bike.current_stolen_record).to have_attributes(street: "278 Broadway", city: "New York",
      theft_description: "Locked to a rack outside the coffee shop", police_report_number: "8675309",
      phone: "5550000000")
    # Entered in the browser's zone, which posts alongside it rather than the server's -
    # so it reads back as the time that was typed, wherever the server happens to be
    browser_zone = page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")
    expect(bike.current_stolen_record.date_stolen.in_time_zone(browser_zone).strftime("%Y-%m-%dT%H:%M"))
      .to eq "2026-08-05T14:30"
    # Signed in as the account the link made, so the checklist knows what's already done
    expect(page).to have_css("li.completed-item", text: "Report theft on Bike Index")
    expect(page).to have_link("your Police Report Number")

    # An account nobody signed up for, so the terms are the first thing it's asked
    visit "/my_account"
    check "user_terms_of_service"
    click_button "Submit"

    expect(page).to have_current_path("/my_account", wait: 5)
    user = User.last
    expect(user).to have_attributes(email: owner_email, confirmed: true, terms_of_service: true)
    expect(bike.creator_id).to eq user.id
  end

  # form-persist announces its restore once, and controllers are lazily loaded - so a
  # module that lands after the announcement never hears it
  it "reconciles a restored draft into the controllers whose modules arrive after it" do
    start_registration
    click_button "+ Add another color"
    type_into("#bike_secondary_frame_color_id", "Blue")
    click_combobox_option("Blue")
    check "Missing serial"
    expect(page).to have_no_field("bike[serial_number]")

    held = []
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.route(%r{(serial|additional_colors)_controller}, ->(route, request) {
        held << request.url
        sleep 1
        route.continue
      })
    end

    visit page.current_url

    # Both a full second after the restore
    expect(page).to have_field("bike_secondary_frame_color_id", with: "Blue", wait: 10)
    expect(page).to have_checked_field("Missing serial")
    expect(page).to have_no_field("bike[serial_number]")
    # A route that never fired would pass vacuously
    expect(held).to include(a_string_matching(/serial_controller/),
      a_string_matching(/additional_colors_controller/))
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

      # Marking it missing hides the input, which still has to submit the "unknown" it holds
      check "Missing serial"
      expect(page).to have_no_field("bike[serial_number]")

      # user_name is required, so the browser holds the submit without any js of ours -
      # and holds it on that alone, not on the serial it can no longer see
      click_button "Complete Bike Registration"
      expect(page).to have_current_path(/step=2/, url: true)
      expect(Bike.count).to eq 0

      fill_in "bike[user_name]", with: user_name
      click_button "Complete Bike Registration"

      expect(page).to have_content("Registration complete")
      # Their friend's registration to claim, not theirs
      expect(page).to have_content("We've emailed #{friend_email} so they can claim")
      expect(Bike.last).to have_attributes(owner_email: friend_email, owner_name: user_name,
        serial_number: "unknown")
      # What the browser actually posted: a bike built without any serial at all is
      # given "unknown" too (BikeServices::Builder), so the bike alone can't tell a
      # hidden field that submitted from one that didn't
      expect(BParam.last.bike["serial_number"]).to eq "unknown"
    end

    it "marks a registration spam when a bot fills the honeypot, without letting on" do
      start_registration

      # A rider can't see or reach the honeypot, so only a bot fills it in
      honeypot = find_field("Additional", visible: :hidden)
      expect(honeypot[:tabindex]).to eq "-1"
      page.execute_script("arguments[0].value = 'http://spam.example.com'", honeypot)

      type_into("#bike_primary_frame_color_id", "Red")
      click_combobox_option("Red")
      fill_in "bike[serial_number]", with: "XYZ 123"

      # The bot gets the same finished page it would if it had gotten away with it
      click_button "Complete Bike Registration"
      expect(page).to have_content("Registration complete")

      # Spam is outside Bike's default scope, so the registration is in no listing or search
      expect(Bike.count).to eq 0
      bike = Bike.spam.last
      expect(bike).to have_attributes(owner_email:, serial_number: "XYZ 123")
      # And the invitation to claim it, enqueued like any other, mails nothing
      expect { Email::OwnershipInvitationJob.drain }.to_not change(ActionMailer::Base.deliveries, :count)
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
      expect(page).to have_css("h1", text: "Progress saved", wait: 15)
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

      expect(page).to have_css("h1", text: "Progress saved", wait: 15)
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

  # A throttle answers text/plain, which Turbo renders as nothing, and asks to be waited
  # for in tens of seconds - so it can be neither retried silently nor waited out
  describe "a step the server throttles" do
    it "stops retrying, says so, and gives the step back" do
      visit "/register/new"
      attempts = fail_submissions(status: 429, headers: {"retry-after" => "20"})
      submit_step_1

      expect(page).to have_content("try again in a moment")
      # It was told how long the wait is, so it didn't spend its retries finding out
      expect(attempts.length).to eq 1
      # The step is theirs to submit again, rather than a spinner that never resolves
      expect(page).to have_button("Next", disabled: false)
      expect(page).to have_field("b_param[owner_email]", with: owner_email)
      expect(BParam.last.owner_email).to be_blank
    end
  end

  # A 500 carries no retry-after, so it's what the retries actually get spent on
  describe "a step the server keeps failing" do
    it "spends its retries, and spends them again when the rider tries once more" do
      visit "/register/new"
      attempts = fail_submissions(status: 500)
      submit_step_1

      # The submission and its two retries, which back off past Capybara's default wait
      expect(page).to have_content("try again in a moment", wait: 5)
      expect(attempts.length).to eq 3

      # The notice asks for another try, so that try is worth as much as the first
      click_button "Next"
      wait_for { attempts.length == 6 }

      expect(page).to have_button("Next", disabled: false)
      expect(page).to have_field("b_param[owner_email]", with: owner_email)
      expect(BParam.last.owner_email).to be_blank
    end
  end

  # The combobox pages its options into a turbo-frame inside the step's own form, so
  # their responses pass register--retry on the way out - and a failed list isn't a
  # failed submission
  describe "the manufacturer options failing partway down the list" do
    # More than the endpoint's page size, so there's a second page to reach for
    let!(:manufacturers) { 16.times.map { |i| FactoryBot.create(:manufacturer, name: "Surly Bikes #{i}") } }

    # These are built after the outer index load, so the index doesn't know them yet
    before { Autocomplete::Loader.load_all(%w[Manufacturer]) }

    it "leaves the step for the rider to submit" do
      visit "/register/new"
      submissions = []
      failed_options = []

      page.driver.with_playwright_page do |playwright_page|
        playwright_page.route(%r{/register}, ->(route, request) {
          submissions << request.url unless request.method == "GET"
          route.continue
        })
        playwright_page.route(%r{/search/combobox/manufacturers}, ->(route, request) {
          next route.continue unless request.url.include?("page=2")

          failed_options << request.url
          route.fulfill(status: 500, contentType: "text/plain", body: "Nope")
        })
      end

      fill_in "b_param[owner_email]", with: owner_email
      type_into("#b_param_manufacturer_id", "Surly")
      # The list resets its scroll as it re-renders, so scrolling before the whole first
      # page is there goes nowhere
      expect(page).to have_css(".hw-combobox__option", text: "Surly Bikes 7")
      find(".hw-combobox__listbox").scroll_to(:bottom)
      wait_for { failed_options.any? }
      # A non-event is only provable by waiting: a scheduled retry is 500ms behind
      sleep 1

      # Still theirs to submit - and their own click is the only thing that does
      click_combobox_option("Surly Bikes 0")
      click_button "Next"

      wait_for_details_step
      expect(submissions.length).to eq 1
    end
  end
end
