# frozen_string_literal: true

require "rails_helper"

# This spec covers the claim-via-email signup path: a signed-in user has a bike
# registered to someone else's email, the recipient follows the link from the
# claim email and signs up, and the bike is auto-claimed without requiring a
# separate confirmation-email round-trip. The bike-creation form itself is
# covered by spec/requests/bikes/create_request_spec.rb.
RSpec.describe "Claim registration signup", :js, type: :system do
  let(:registrar) { FactoryBot.create(:user_confirmed) }
  let(:claimer_email) { "claimer@example.com" }
  let(:bike) { FactoryBot.create(:bike, creator: registrar, owner_email: claimer_email) }
  let!(:ownership) { FactoryBot.create(:ownership, bike:, creator: registrar, owner_email: claimer_email) }

  before do
    # Avoid ReadOnlyError when the bike show page touches gear types
    RearGearType.fixed
    FrontGearType.fixed
  end

  it "auto-confirms and claims after the recipient follows the email link and signs up" do
    # Sign in as the registrar
    visit new_session_path
    fill_in "Email", with: registrar.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in", wait: 5)

    expect(ownership.owner_email).to eq claimer_email
    expect(ownership.claimed?).to be_falsey
    expect(ownership.token).to be_present

    # Send the claim email and grab the "Claim the bike" link out of the body.
    # That link points to the bike show page with the ownership token; visiting
    # it primes session[:claim_token_email] so the subsequent signup auto-confirms.
    expect {
      Email::OwnershipInvitationJob.new.perform(ownership.id)
    }.to change(ActionMailer::Base.deliveries, :count).by(1)
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

    expect(find_field("Email").value).to eq claimer_email
    fill_in "Name", with: "New Claimer"
    fill_in "Password", with: "testthisthing7$"
    check "user_terms_of_service"
    click_button "Sign up"
    expect(page).to have_no_current_path(new_user_path, wait: 5)

    new_user = User.find_by(email: claimer_email)
    expect(new_user).to be_present
    expect(new_user.name).to eq "New Claimer"
    # The session[:claim_token_email] set when we visited the bike link
    # auto-confirms the user on signup (ControllerHelpers#confirm_user_from_claim_token)
    expect(new_user.confirmed?).to be_truthy

    # The return_to from /users/new is the bike show page with the token,
    # which displays the "Claim {bike_type}" CTA linking to /ownerships/:id
    expect(page).to have_link("Claim bike", wait: 5)
    click_link "Claim bike"
    expect(page).to have_content("you just claimed it", wait: 5)
    expect(ownership.reload.claimed?).to be_truthy
    expect(ownership.user_id).to eq new_user.id
  end
end
