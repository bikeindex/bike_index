# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Signup", :js, type: :system do
  let(:email) { "newrider@msu.edu" }
  let(:password) { "a-long-enough-password" }

  # Signing up leaves them passwordless, and the emailed link is the only way out of that -
  # so both examples start here, signed in and nudged to set a password
  def sign_up_and_confirm
    visit new_user_path
    expect(page).to have_no_field("Password")

    fill_in "Email", with: email
    fill_in "Name", with: "New Rider"
    check "user_terms_of_service"

    expect { click_button "Sign up" }.to change(Email::ConfirmationJob.jobs, :count).by(1)
    expect(page).to have_content("Follow the link in the email to finish signing up", wait: 10)

    user = User.find_by(email:)
    expect(user.passwordless_user?).to be_truthy
    expect(user.confirmed?).to be_falsey

    Email::ConfirmationJob.drain
    # The interstitial waits for a click; that the GET alone doesn't confirm is
    # users_request_spec's job
    visit emailed_path("/users/confirm")
    expect(user.reload.confirmed?).to be_falsey
    click_button "Sign in"
    expect(page).to have_link("set a password to sign in", wait: 10)
    expect(user.reload.confirmed?).to be_truthy

    dismiss_donation_modal

    user
  end

  def emailed_path(path)
    body = ActionMailer::Base.deliveries.last.html_part.body.decoded
    link = Nokogiri::HTML(body).css("a").map { |a| a["href"] }.compact.find { |href| href.include?(path) }
    expect(link).to be_present
    URI(link).request_uri
  end

  it "sets a password from the nudge, then signs back in with it" do
    user = sign_up_and_confirm

    click_link "set a password to sign in"
    expect(page).to have_field("Update your password")

    fill_in "Update your password", with: password
    fill_in "Password confirmation", with: password
    click_button "Update password"

    expect(page).to have_content("Password reset successfully", wait: 10)
    # The nudge is gone once they have a password - it's what sign_in_flash renders instead
    expect(page).to have_no_link("set a password to sign in")
    expect(user.reload.passwordless_user?).to be_falsey

    visit "/logout"
    visit new_session_path
    fill_in "Email", with: email

    # No longer passwordless, so identify asks for the password rather than emailing a link
    expect { click_button "Continue" }.to_not change(Email::MagicLoginLinkJob.jobs, :count)

    fill_in "Password", with: password
    click_button "Log in"

    expect(page).to have_content("Logged in!", wait: 10)
  end

  it "email bans a bot that fills the honeypot, without letting on" do
    visit new_user_path

    # A rider can't see or reach the honeypot, so only a bot fills it in
    honeypot = find_field("Additional", visible: :hidden)
    expect(honeypot[:tabindex]).to eq "-1"
    page.execute_script("arguments[0].value = 'http://spam.example.com'", honeypot)

    fill_in "Email", with: email
    fill_in "Name", with: "Spam Bot"
    check "user_terms_of_service"

    # The bot gets the same success it would if it had gotten away with it
    expect { click_button "Sign up" }.to change(Email::ConfirmationJob.jobs, :count).by(1)
    expect(page).to have_content("Follow the link in the email to finish signing up", wait: 10)

    user = User.find_by(email:)
    expect(user.email_banned?).to be_truthy
    expect(user.email_bans.last.reason).to eq "honeypot"

    # The ban empties the confirmation email, so the account can never be activated
    expect { Email::ConfirmationJob.drain }.to_not change(ActionMailer::Base.deliveries, :count)
    expect(user.reload.confirmed?).to be_falsey
  end

  it "signs in with a magic link, then confirms an additional email" do
    user = sign_up_and_confirm
    additional_email = "newrider@umich.edu"

    visit "/logout"
    visit new_session_path
    fill_in "Email", with: email

    # Still passwordless, so identify emails the link instead of asking for a password
    expect { click_button "Continue" }.to change(Email::MagicLoginLinkJob.jobs, :count).by(1)
    expect(page).to have_content("Follow the link in the email to sign in!")

    Email::MagicLoginLinkJob.drain
    visit emailed_path("/session/magic_link")
    click_button "Sign in"
    expect(page).to have_link("set a password to sign in", wait: 10)

    click_link "Update your profile"
    wait_for_page_script
    click_link "Add additional email"
    fill_in "Additional email", with: additional_email

    # The form has a save button at the top and the bottom - this is the one by the field
    expect { within(".extra-footer-save") { click_button "Save changes" } }
      .to change(Email::AdditionalEmailConfirmationJob.jobs, :count).by(1)
    user_email = user.user_emails.find_by(email: additional_email)
    expect(user_email.confirmed?).to be_falsey

    Email::AdditionalEmailConfirmationJob.drain
    visit emailed_path("/user_emails/#{user_email.id}/confirm")
    click_button "Confirm email"

    expect(page).to have_content("has been confirmed and added to your account", wait: 10)
    expect(user_email.reload.confirmed?).to be_truthy
  end
end
