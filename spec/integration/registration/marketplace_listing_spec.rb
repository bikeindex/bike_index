# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Listing a registration on the marketplace", :js, type: :system do
  let(:owner_email) { "seller@bikeindex.org" }
  let(:buyer_email) { "buyer@bikeindex.org" }
  let!(:seller) { FactoryBot.create(:user_confirmed, email: owner_email) }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }
  let!(:state) { FactoryBot.create(:state_new_york) }
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Commuting") }

  # Every phase here opens on a navigation, and the two-step login alone outruns
  # Capybara's 2s default
  around { |example| Capybara.using_wait_time(10) { example.run } }

  before do
    # The manufacturer combobox autocompletes against the redis index
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
    # The legacy bike show builds these gear records lazily, and its render can't write
    RearGearType.fixed
    FrontGearType.fixed
  end

  def address_field(attribute) = "marketplace_listing[address_record_attributes][#{attribute}]"

  # Only the seller signs in - the buyer arrives signed in off their confirmation link
  def sign_in_as_seller
    visit new_session_path
    fill_in "Email", with: owner_email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_current_path("/my_account")
    dismiss_donation_modal(wait: 10)
  end

  def open_settings_menu = find("button[aria-label='Settings']").click

  def sign_out
    open_settings_menu
    click_link "Log out"
    expect(page).to have_content("Logged out")
  end

  # flaky: step 2 is typed into as soon as it hydrates, the same race register_spec carries
  # retries for - seen twice locally in ~40 runs, once as the color combobox refusing to
  # filter and once as both plain fills arriving empty. Neither CPU throttling nor holding
  # form_persist_controller and autofocus_controller on the route reproduces it, so
  # wait_for_stimulus above is not the gap; the retries stand in for a fix
  it "publishes a registration for sale, sells it through a buyer's message, and transfers it", flaky: 4 do
    sign_in_as_seller

    # ---- Register the bike ----
    visit "/register/new"
    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"

    # fill_in sends its text a round trip later, so a controller connecting in between
    # lands it in the field filled just before
    expect(page).to have_content("Add your bike")
    expect(page).to have_css("input[name='bike[frame_model]']:focus")
    wait_for_stimulus

    type_into("#bike_primary_frame_color_id", "Red")
    click_combobox_option("Red")
    fill_in "bike[frame_model]", with: "Cross Check"
    fill_in "bike[serial_number]", with: "MKT12345"

    # A lost fill leaves the serial empty and the browser holds the submit, so without this
    # the flake below surfaces 10s later as a missing "Registration complete"
    expect(page).to have_field("bike[serial_number]", with: "MKT12345")
    click_button "Complete Bike Registration"

    expect(page).to have_content("Registration complete")
    bike = Bike.last
    # Nothing in the flow asks for a primary activity, and publishing is what needs one
    expect(bike).to have_attributes(owner_email:, serial_number: "MKT12345",
      frame_model: "Cross Check", current_marketplace_listing: nil, primary_activity_id: nil)

    # ---- Into the listing form, from the registration it's for ----
    click_link "View your registration"
    expect(page).to have_current_path(bike_path(bike), ignore_query: true)
    click_link "Edit"
    click_link "List for sale"

    # Nothing saved yet, so there's nothing to preview
    expect(page).to have_content("Save the listing to be able to preview it")
    expect(page).to have_no_css("li.completed-item")

    # revised/init.coffee selectizes this one select, so it has no <select> to pick from
    within(".fancy-select-placeholder") do
      find(".selectize-input").click
      find(".selectize-dropdown-content .option", text: primary_activity.name).click
    end
    select "excellent - lightly ridden", from: "marketplace_listing[condition]"
    fill_in "Price", with: "450"
    check "marketplace_listing[price_negotiable]"
    fill_in "marketplace_listing[description]", with: "Selling because I moved"

    # The US is what reveals the state select; until it's picked the region is free text
    expect(page).to have_no_select(address_field("region_record_id"))
    select "United States", from: address_field("country_id")
    select state.name, from: address_field("region_record_id")
    fill_in address_field("city"), with: "New York"
    fill_in address_field("postal_code"), with: "10007"

    # The publish toggle's checkbox is sr-only, so the switch a seller clicks is its label
    find("label", text: "For sale").click
    click_button "Save changes", match: :first

    expect(page).to have_content("It is now listed for sale")
    expect(page).to have_content("Listing is published")

    marketplace_listing = bike.reload.current_marketplace_listing
    expect(marketplace_listing).to have_attributes(status: "for_sale", condition: "excellent",
      amount_cents: 45000, price_negotiable: true, description: "Selling because I moved",
      seller_id: seller.id, published_at: be_present)
    expect(marketplace_listing.address_record).to have_attributes(city: "New York",
      postal_code: "10007", region_record_id: state.id, country_id: Country.united_states_id,
      kind: "marketplace_listing", user_id: seller.id)
    expect(bike).to have_attributes(is_for_sale: true, primary_activity_id: primary_activity.id)

    # ---- The listing as the registration now reads ----
    click_link "View your listing"

    expect(page).to have_css(".bike-status-html", text: /for sale/i)
    expect(page).to have_content("$450")
    expect(page).to have_content("price is negotiable")
    expect(page).to have_content("lightly ridden")
    expect(page).to have_content("Selling because I moved")

    sign_out

    # ---- A buyer, signed out, tries to contact the seller ----
    visit bike_path(bike)
    click_link "contact the owner"

    # Meant to ask for an account, but Sessionable's translation_key: :create_account is
    # dropped by store_return_and_authenticate_user - dead since #2810 added both. So it
    # asks for a login, and the email step carries an unknown address on to signing up
    expect(page).to have_content("you have to log in")
    expect(page).to have_current_path(new_session_path, ignore_query: true)
    fill_in "Email", with: buyer_email
    click_button "Continue"

    expect(page).to have_current_path(new_user_path, ignore_query: true)
    expect(page).to have_field("Email", with: buyer_email)
    fill_in "Name", with: "Bianca Buyer"
    check "user_terms_of_service"
    expect { click_button "Sign up" }.to change(Email::ConfirmationJob.jobs, :count).by(1)

    # Signing up leaves them unconfirmed, which is its own gate ahead of the message
    expect(page).to have_content("Follow the link in the email to finish signing up")
    buyer = User.find_by(email: buyer_email)
    expect(buyer.confirmed?).to be_falsey

    # Confirming spends the return_to stored when they clicked "contact the owner"
    Email::ConfirmationJob.drain
    visit emailed_path("/users/confirm")
    click_button "Sign in"

    expect(page).to have_current_path(my_account_message_path("ml_#{marketplace_listing.id}"))
    expect(buyer.reload.confirmed?).to be_truthy

    fill_in "Subject", with: "Is the Cross Check still available?"
    fill_in "marketplace_message[body]", with: "I'd like to come see it this weekend"
    click_button "Send message"

    expect(page).to have_content("Message sent")
    expect(page).to have_current_path(my_account_messages_path, ignore_query: true)
    marketplace_message = MarketplaceMessage.last
    expect(marketplace_message).to have_attributes(sender_id: buyer.id, receiver_id: seller.id,
      marketplace_listing_id: marketplace_listing.id, kind: "sender_buyer",
      subject: "Is the Cross Check still available?")

    # Delivering touches the seller, expiring the cached "no messages" that hides their
    # menu item
    expect { Email::MarketplaceMessageJob.drain }.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq([owner_email])

    sign_out

    # ---- The seller sells it, which transfers the registration to the buyer ----
    sign_in_as_seller
    open_settings_menu
    click_link "Marketplace messages"

    click_link "Is the Cross Check still available?"
    expect(page).to have_content("I'd like to come see it this weekend")

    click_link "Mark bike sold to"
    fill_in "Amount sold for", with: "425"
    click_button "Record sale"

    expect(page).to have_content("Bike marked sold and transferred")
    sale = Sale.last
    expect(sale).to have_attributes(seller_id: seller.id, amount_cents: 42500,
      sold_via: "bike_index_marketplace", new_owner_email: buyer_email,
      marketplace_message_id: marketplace_message.id)

    # The transfer runs in the sale's create callback
    CallbackJobs::AfterSaleCreateJob.drain

    expect(marketplace_listing.reload).to have_attributes(status: "sold", buyer_id: buyer.id)
    expect(bike.reload.current_ownership).to have_attributes(owner_email: buyer_email,
      sale_id: sale.id, claimed?: false)
    expect(bike.is_for_sale?).to be_falsey
  end
end
