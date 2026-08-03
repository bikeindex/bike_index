# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passwordless signup", :js, type: :system do
  let(:email) { "newrider@msu.edu" }

  it "signs up without a password and the emailed link signs them in" do
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
    body = ActionMailer::Base.deliveries.last.html_part.body.decoded
    confirm_link = Nokogiri::HTML(body).css("a").map { |a| a["href"] }.compact
      .find { |href| href.include?("/users/confirm") }
    expect(confirm_link).to be_present

    # The link is a GET, so it lands on the interstitial -- which posts itself
    visit URI(confirm_link).request_uri
    expect(page).to have_link("set password to sign in", wait: 10)
    expect(user.reload.confirmed?).to be_truthy
  end
end
