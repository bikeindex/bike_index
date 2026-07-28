# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Register flow", :js, type: :system do
  let(:owner_email) { "owner@example.com" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }
  let!(:blue) { FactoryBot.create(:color, name: "Blue") }
  let!(:green) { FactoryBot.create(:color, name: "Green") }

  before do
    # The manufacturer combobox autocompletes against the redis index
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  # Through step_1 and onto step_2, the way a rider gets there
  def start_registration
    visit "/register/new"

    # new creates the registration and lands on its tokenized step_1
    expect(page).to have_current_path(/register\/step_1\?b_param_token=/, url: true)

    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    expect(page).to have_content("Add your bike")
  end

  it "starts a registration, keeps a full details draft across a reload, and completes" do
    visit "/register/new"

    # new creates the registration and lands on its tokenized step_1
    expect(page).to have_current_path(/register\/step_1\?b_param_token=/, url: true)

    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    expect(page).to have_content("Add your bike")
    details_url = page.current_url
    expect(details_url).to match(/register\/step_2\?b_param_token=/)

    # The browser back button returns to step_1 on the same registration, prefilled
    page.go_back
    expect(page).to have_field("b_param_manufacturer_id", with: "Surly")
    expect(page).to have_field("b_param[owner_email]", with: owner_email)
    click_button "Next"
    expect(page).to have_current_path(details_url, url: true)

    # Fill every field: text, chip radio, comboboxes (including the collapsed
    # additional-color rows) and the missing-serial checkbox
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
    check "Missing serial"
    expect(page).to have_field("bike[serial_number]", with: "unknown")
    fill_in "bike[bike_sticker]", with: "A 471 829"
    fill_in "bike[phone]", with: "(555) 000-0000"

    # Nothing submitted yet - the reload restores the whole draft from form-persist
    visit details_url

    expect(page).to have_field("bike[frame_model]", with: "Marlin 7")
    expect(page).to have_field("bike[year]", with: "2023")
    expect(page).to have_field("bike_primary_frame_color_id", with: "Red")
    expect(find("input[name='bike[primary_frame_color_id]']", visible: :all).value).to eq red.id.to_s
    # The restored additional colors reveal their collapsed rows and use up the add button
    expect(page).to have_field("bike_secondary_frame_color_id", with: "Blue")
    expect(page).to have_field("bike_tertiary_frame_color_id", with: "Green")
    expect(page).to have_no_button("+ Add another color")
    expect(find("input[name='bike[frame_size]'][value='m']", visible: :all)).to be_checked
    # The restored missing serial re-reveals the made-without link
    expect(page).to have_field("bike[serial_number]", with: "unknown")
    expect(page).to have_checked_field("Missing serial")
    expect(page).to have_button("This bike was made without a serial number")
    expect(page).to have_field("bike[bike_sticker]", with: "A 471 829")
    expect(page).to have_field("bike[phone]", with: "(555) 000-0000")

    # Picking a photo uploads it straight to storage; the form carries only the signed id
    attach_file("register_photo", Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg"), make_visible: true)
    expect(page).to have_content("bike_photo-landscape.jpeg")
    expect(page).to have_no_content("uploading")

    click_button "Complete Bike Registration"

    expect(page).to have_content("Registration complete")
    expect(page).to have_content("verify your email")
    b_param = BParam.last
    expect(b_param.bike).to include("frame_model" => "Marlin 7", "year" => "2023",
      "primary_frame_color_id" => red.id.to_s, "secondary_frame_color_id" => blue.id.to_s,
      "tertiary_frame_color_id" => green.id.to_s, "frame_size" => "m",
      "serial_number" => "unknown", "phone" => "(555) 000-0000")
    expect(b_param.details_completed?).to be_truthy
    expect(ActiveStorage::Blob.find_signed!(b_param.image_signed_id).filename.to_s)
      .to eq "bike_photo-landscape.jpeg"
  end

  # The example above uploads to the Disk service, same-origin, which never exercises a presigned
  # S3 PUT or a cross-origin request. This one goes to the bikeindex-test R2 bucket for real, so
  # it needs credentials and the network. Kept separate so an R2 blip can't take the whole flow's
  # coverage with it - and signed in, because a bike (and so a PublicImage) is what has a url.
  describe "uploading to R2" do
    let(:image_path) { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }
    let(:current_user) { FactoryBot.create(:user_confirmed, email: owner_email) }

    before do
      skip "needs the bikeindex-test R2 credentials (R2_TEST_* in .env.test)" if ENV["R2_TEST_ACCESS_KEY"].blank?
      visit new_session_path
      fill_in "Email", with: current_user.email
      click_button "Continue"
      fill_in "Password", with: "testthisthing7$"
      click_button "Log in"
      expect(page).to have_current_path("/my_account", wait: 5)
    end

    # class_attribute, so the Capybara server thread picks it up too. VCR blocks un-cassetted
    # http, and the browser's PUT can't be cassetted anyway - it isn't a ruby request.
    around do |example|
      default_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:cloudflare_test)
      # disable!/enable! rather than allow_net_connect!, which would restore a different
      # config than VCR installed and leak that to later examples
      VCR.turned_off(ignore_cassettes: true) do
        WebMock.disable!
        example.run
      ensure
        WebMock.enable!
      end
    ensure
      ActiveStorage::Blob.service = default_service
    end

    # However far the example got, don't leave objects in the bucket. `delete` rather than
    # `purge`: the blob is attached, so purge's destroy hits a foreign key, gets rescued, and
    # never reaches storage - the rows go with the transaction anyway.
    after do
      VCR.turned_off(ignore_cassettes: true) do
        WebMock.disable!
        ActiveStorage::Blob.where(service_name: "cloudflare_test").each(&:delete)
      ensure
        WebMock.enable!
      end
    end

    it "PUTs the photo to the bucket and serves it from the storage domain" do
      start_registration

      attach_file("register_photo", image_path, make_visible: true)
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
end
