# frozen_string_literal: true

RSpec.shared_context :signup_flow_steps do
  let(:email) { "newrider@msu.edu" }

  # Signing up leaves them passwordless, and the emailed link is the only way out of that -
  # so every example starts here, signed in and nudged to set a password. No step of it needs
  # JavaScript, which is why the no-JS example shares it
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

    user
  end
end
