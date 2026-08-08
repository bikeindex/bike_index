# frozen_string_literal: true

require "rails_helper"

# The whole point of the interstitial is the POST it makes without being clicked — request
# specs post directly, so this is the only place the Stimulus controller actually runs
RSpec.describe Sessions::SignInInterstitial::Component, :js, type: :system do
  let(:base_url) { "/rails/view_components/sessions/sign_in_interstitial/component" }

  it "posts itself on load, and waits for the reader when auto_submit is off" do
    visit "#{base_url}/auto_submitting"

    # The token is never valid, so the POST lands back on the magic link form
    expect(page).to have_current_path(/session\/magic_link/, url: true, wait: 10)
    expect(page).to have_text("Unable to authenticate that token")

    visit "#{base_url}/default"

    expect(page).to have_button("Sign in")
    expect_axe_clean
    # Still on the preview — nothing submitted on its own
    expect(page).to have_current_path("#{base_url}/default", wait: 5)
  end
end
