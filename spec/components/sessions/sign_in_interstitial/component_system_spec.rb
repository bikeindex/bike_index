# frozen_string_literal: true

require "rails_helper"

# Request specs post directly, so this is the only place the auto-submit Stimulus controller
# actually runs — and the only place that proves the default really doesn't submit itself
RSpec.describe Sessions::SignInInterstitial::Component, :js, type: :system do
  let(:base_url) { "/rails/view_components/sessions/sign_in_interstitial/component" }

  it "posts itself when auto_submit is on, and waits for the reader by default" do
    visit "#{base_url}/auto_submitting"

    # The token is never valid, so the POST lands back on the magic link form
    expect(page).to have_current_path(/session\/magic_link/, url: true, wait: 10)

    # auto_submit off, so the button is still there to be found - it posts to "#", which
    # would navigate off this preview if it fired
    visit "#{base_url}/default"

    expect(page).to have_button("Sign in")
    expect_axe_clean
  end
end
