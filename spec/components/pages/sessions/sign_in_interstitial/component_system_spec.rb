# frozen_string_literal: true

require "rails_helper"

# Request specs post directly, so only a real browser can prove the form doesn't submit itself
RSpec.describe Pages::Sessions::SignInInterstitial::Component, :js, type: :system do
  let(:base_url) { "/rails/view_components/pages/sessions/sign_in_interstitial/component" }

  it "leaves the submitting to the reader" do
    visit "#{base_url}/default"

    # It posts to "#", so submitting on render would navigate off this preview
    expect(page).to have_button("Sign in")
    expect(page).to have_current_path("#{base_url}/default")
    expect_axe_clean
  end
end
