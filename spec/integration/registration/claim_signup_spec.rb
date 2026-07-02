# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Claim registration signup", :js, type: :system do
  let(:registrar) { FactoryBot.create(:user_confirmed) }
  let(:claimer_email) { "claimer@example.com" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:black) { Color.black }

  before do
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
    # Avoid ReadOnlyError on the bike show page in test mode
    RearGearType.fixed
    FrontGearType.fixed
  end

  def selectize_for(field_id)
    find("##{field_id}", visible: :all).find(:xpath, "./following-sibling::div[contains(@class, 'selectize-control')][1]")
  end

  def pick_selectize_option(field_id, text)
    container = selectize_for(field_id)
    container.find(".selectize-input").click
    container.find(".selectize-dropdown-content .option", text: text, wait: 5).click
  end

  it "registers a bike to another email, signs out, and the recipient signs up via the claim email link" do
    # Sign in as the registrar
    visit new_session_path
    fill_in "Email", with: registrar.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in", wait: 5)

    # Register a bike to a different owner email
    visit "/bikes/new"
    fill_in "Serial number", with: "ABC123XYZ"

    # Manufacturer field is a text input enhanced by selectize + remote autocomplete
    manufacturer_box = selectize_for("bike_manufacturer_id")
    manufacturer_box.find(".selectize-input").click
    manufacturer_box.find(".selectize-input input").set("Surly")
    expect(page).to have_css(".selectize-dropdown-content .option", text: "Surly", wait: 5)
    find(".selectize-dropdown-content .option", text: "Surly").click

    pick_selectize_option("bike_primary_frame_color_id", "Black")
    fill_in "Owner email", with: claimer_email

    expect {
      click_button "Register"
      expect(page).to have_content("successfully added", wait: 10)
    }.to change(Email::OwnershipInvitationJob.jobs, :count).by(1)

    bike = Bike.last
    ownership = bike.current_ownership
    expect(ownership.owner_email).to eq claimer_email
    expect(ownership.creator_id).to eq registrar.id
    expect(ownership.claimed?).to be_falsey
    expect(ownership.token).to be_present

    # Deliver the claim email and grab the "Claim the bike" link out of the body.
    # That link points to the bike show page with the ownership token; visiting it
    # primes session[:claim_token_email] so the subsequent signup auto-confirms.
    Email::OwnershipInvitationJob.drain
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to include claimer_email
    body = mail.html_part&.body&.decoded || mail.body.decoded
    hrefs = Nokogiri::HTML(body).css("a").map { |a| a["href"] }.compact
    claim_link = hrefs.find { |href| href.include?("/bikes/#{bike.id}") && href.include?("t=#{ownership.token}") }
    expect(claim_link).to be_present
    claim_path = URI(claim_link).request_uri

    # Sign out via the UI
    visit "/logout"
    expect(page).to have_content("Logged out!", wait: 5)

    # Follow the link from the claim email -- lands on the bike show page,
    # which sets session[:claim_token_email] and renders a "sign up" CTA
    visit claim_path
    expect(page).to have_link("sign up", wait: 5)
    click_link "sign up"

    # Retrying matcher (not find_field(...).value, which reads once) so the
    # assertion waits for the signup page to finish loading after the click.
    expect(page).to have_field("Email", with: claimer_email)
    fill_in "Name", with: "New Claimer"
    fill_in "Password", with: "testthisthing7$"
    check "user_terms_of_service"
    click_button "Sign up"
    # The session[:claim_token_email] set when we visited the bike link
    # auto-confirms the user on signup (ControllerHelpers#confirm_user_from_claim_token),
    # so the return_to redirects past please_confirm_email to the bike show page
    # with the "Claim {bike_type}" CTA. Waiting for that link is the sync barrier.
    expect(page).to have_link("Claim bike", wait: 10)

    new_user = User.find_by(email: claimer_email)
    expect(new_user).to be_present
    expect(new_user.name).to eq "New Claimer"
    expect(new_user.confirmed?).to be_truthy

    click_link "Claim bike"
    expect(page).to have_content("you just claimed it", wait: 5)
    expect(ownership.reload.claimed?).to be_truthy
    expect(ownership.user_id).to eq new_user.id
  end
end
