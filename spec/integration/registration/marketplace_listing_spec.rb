# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Listing a registration on the marketplace", :js, type: :system do
  let(:owner_email) { "seller@bikeindex.org" }
  let(:buyer_email) { "buyer@bikeindex.org" }
  let(:buyer_name) { "Bianca Buyer" }
  let!(:current_user) { FactoryBot.create(:user_confirmed, email: owner_email) }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }
  let!(:state) { FactoryBot.create(:state_new_york) }
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Commuting") }

  before do
    # The manufacturer combobox autocompletes against the redis index
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
    # The registration's bike details render creates these lazily, which is read-only mid-request
    RearGearType.fixed
    FrontGearType.fixed
  end

  # The publish toggle's checkbox is sr-only, so the switch a seller clicks is its label
  def publish_toggle = find("label", text: "For sale")

  def address_field(attribute) = "marketplace_listing[address_record_attributes][#{attribute}]"

  # revised/init.coffee selectizes this one select, so it has no <select> to pick from
  def pick_primary_activity(name)
    within(".fancy-select-placeholder") do
      find(".selectize-input").click
      find(".selectize-dropdown-content .option", text: name, wait: 5).click
    end
  end

  def sign_in(email)
    visit new_session_path
    fill_in "Email", with: email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_current_path("/my_account", wait: 5)
    # my_account renders the donation modal at the foot of a long page, and
    # dismiss_donation_modal's own presence check doesn't wait for it
    expect(page).to have_css("#donationModal", visible: :all, wait: 10)
    dismiss_donation_modal
  end

  def open_settings_menu = find("button[aria-label='Settings']").click

  def sign_out
    open_settings_menu
    click_link "Log out"
    expect(page).to have_content("Logged out", wait: 10)
  end

  # The link out of the mail just delivered, minus the mailer's host - the app is on Capybara's
  def emailed_path(path)
    body = ActionMailer::Base.deliveries.last.html_part.body.decoded
    link = Nokogiri::HTML(body).css("a").map { |a| a["href"] }.compact.find { |href| href.include?(path) }
    expect(link).to be_present
    URI(link).request_uri
  end

  it "publishes a registration for sale, sells it through a buyer's message, and transfers it" do
    sign_in(owner_email)

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

    fill_in "bike[frame_model]", with: "Cross Check"
    fill_in "bike[serial_number]", with: "MKT12345"
    type_into("#bike_primary_frame_color_id", "Red")
    click_combobox_option("Red")
    click_button "Complete Bike Registration"

    expect(page).to have_content("Registration complete")
    bike = Bike.last
    expect(bike).to have_attributes(owner_email:, serial_number: "MKT12345", frame_model: "Cross Check")
    expect(bike.current_marketplace_listing).to be_blank
    # Nothing in the flow asks for one, and publishing is what needs it
    expect(bike.primary_activity_id).to be_blank

    # ---- Into the listing form, from the registration it's for ----
    click_link "View your registration"
    expect(page).to have_current_path(bike_path(bike), ignore_query: true, wait: 10)
    click_link "Edit"
    click_link "List for sale"

    expect(page).to have_content("Listing draft", wait: 10)
    # Nothing saved yet, so there's no listing to preview and nothing required filled in
    expect(page).to have_no_link("Preview the listing")
    expect(page).to have_content("Save the listing to be able to preview it")
    expect(page).to have_no_css("li.completed-item")

    pick_primary_activity(primary_activity.name)
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

    publish_toggle.click
    click_button "Save changes", match: :first

    expect(page).to have_content("It is now listed for sale", wait: 10)
    expect(page).to have_content("Listing is published")

    marketplace_listing = bike.reload.current_marketplace_listing
    expect(marketplace_listing).to have_attributes(status: "for_sale", condition: "excellent",
      amount_cents: 45000, price_negotiable: true, description: "Selling because I moved",
      seller_id: current_user.id)
    expect(marketplace_listing.published_at).to be_present
    expect(marketplace_listing.address_record).to have_attributes(city: "New York",
      postal_code: "10007", region_record_id: state.id, country_id: Country.united_states_id,
      kind: "marketplace_listing", user_id: current_user.id)
    expect(bike.is_for_sale?).to be_truthy
    expect(bike.primary_activity_id).to eq primary_activity.id

    # ---- The listing as the registration now reads ----
    click_link "View your listing"

    expect(page).to have_css(".bike-status-html", text: /for sale/i, wait: 10)
    expect(page).to have_content("$450")
    expect(page).to have_content("price is negotiable")
    expect(page).to have_content("lightly ridden")
    expect(page).to have_content("Selling because I moved")

    sign_out

    # ---- A buyer, signed out, tries to contact the seller ----
    ActionMailer::Base.deliveries = []
    visit bike_path(bike)
    click_link "contact the owner"

    # Messaging needs an account, and this asks them to log in - it's the email step that
    # sends an address nobody has signed up with on to signing up
    expect(page).to have_content("you have to log in", wait: 10)
    expect(page).to have_current_path(new_session_path, ignore_query: true)
    fill_in "Email", with: buyer_email
    click_button "Continue"

    expect(page).to have_current_path(new_user_path, ignore_query: true, wait: 10)

    expect(page).to have_field("Email", with: buyer_email)
    fill_in "Name", with: buyer_name
    check "user_terms_of_service"
    expect { click_button "Sign up" }.to change(Email::ConfirmationJob.jobs, :count).by(1)

    # Signing up leaves them unconfirmed, which is its own gate ahead of the message
    expect(page).to have_content("Follow the link in the email to finish signing up", wait: 10)
    buyer = User.find_by(email: buyer_email)
    expect(buyer.confirmed?).to be_falsey

    # Confirming is what spends the return_to stored when they clicked "contact the owner",
    # so the emailed link lands them back on the message they came to send
    Email::ConfirmationJob.drain
    visit emailed_path("/users/confirm")
    click_button "Sign in"

    expect(page).to have_current_path(my_account_message_path("ml_#{marketplace_listing.id}"), wait: 10)
    expect(buyer.reload.confirmed?).to be_truthy
    expect(page).to have_content("New message")

    fill_in "Subject", with: "Is the Cross Check still available?"
    fill_in "marketplace_message[body]", with: "I'd like to come see it this weekend"
    click_button "Send message"

    expect(page).to have_content("Message sent", wait: 10)
    expect(page).to have_current_path(my_account_messages_path, ignore_query: true)
    marketplace_message = MarketplaceMessage.last
    expect(marketplace_message).to have_attributes(sender_id: buyer.id, receiver_id: current_user.id,
      marketplace_listing_id: marketplace_listing.id, kind: "sender_buyer",
      subject: "Is the Cross Check still available?")

    # The notification is how the seller hears about it, and delivering it touches them -
    # which is what expires the cached "no messages" their menu item is missing for
    expect { Email::MarketplaceMessageJob.drain }.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq([owner_email])

    sign_out

    # ---- The seller sells it, which transfers the registration to the buyer ----
    sign_in(owner_email)
    open_settings_menu
    click_link "Marketplace messages"

    expect(page).to have_content("Marketplace messages", wait: 10)
    click_link "Is the Cross Check still available?"

    expect(page).to have_content("I'd like to come see it this weekend", wait: 10)
    click_link "Mark bike sold to"

    # A turbo-stream swap of the button for the form it names
    expect(page).to have_field("Amount sold for", wait: 10)
    fill_in "Amount sold for", with: "425"
    click_button "Record sale"

    expect(page).to have_content("Bike marked sold and transferred", wait: 10)
    sale = Sale.last
    expect(sale).to have_attributes(seller_id: current_user.id, amount_cents: 42500,
      sold_via: "bike_index_marketplace", new_owner_email: buyer_email,
      marketplace_message_id: marketplace_message.id)

    # The transfer runs in the sale's callback, which is why create redirects away rather
    # than showing it happening
    CallbackJobs::AfterSaleCreateJob.drain

    expect(marketplace_listing.reload).to have_attributes(status: "sold", buyer_id: buyer.id)
    expect(bike.reload.current_ownership).to have_attributes(owner_email: buyer_email,
      sale_id: sale.id, claimed?: false)
    expect(bike.is_for_sale?).to be_falsey
  end
end
