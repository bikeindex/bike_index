# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Turnstile::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/turnstile/component/" }
  # Cloudflare's dummy sitekey, which issues a token to an automated browser where a
  # real one fails bot detection - so the whole client-side flow runs here
  before do
    stub_const("Integrations::Turnstile::ENABLED", true)
    stub_const("Integrations::Turnstile::SITE_KEY", "1x00000000000000000000AA")
  end

  it "reveals the widget once the address typed in is one Turnstile asks" do
    visit("#{base_path}in_a_form")

    expect(page).to have_field(type: "email")
    expect(page).to have_no_css(".cf-turnstile")
    # api.js ships on the first reveal rather than to everyone who opens the form
    expect(page).to have_no_css("head script[src*='challenges.cloudflare.com']", visible: :all)

    fill_in "you@example.com", with: "rider@gmail.com"
    expect(page).to have_no_css(".cf-turnstile")

    fill_in "you@example.com", with: "rider@yahoo.com"
    expect(page).to have_css(".cf-turnstile")
    expect(page).to have_css("head script[src*='challenges.cloudflare.com']", visible: :all)

    # And back again
    fill_in "you@example.com", with: "rider@gmail.com"
    expect(page).to have_no_css(".cf-turnstile")
  end

  it "renders the widget shown when the address was already submitted, and it issues a token" do
    visit("#{base_path}already_risky")

    expect(page).to have_css(".cf-turnstile")
    # The token the form posts back, which turnstile_verified? checks against siteverify
    expect(page).to have_field(Integrations::Turnstile::RESPONSE_PARAM, type: "hidden",
      with: "XXXX.DUMMY.TOKEN.XXXX", visible: :all, wait: 10)
    # The component renders the tag here, and the controller's guard sees it and doesn't add its own
    expect(page).to have_css("script[src*='challenges.cloudflare.com']", count: 1, visible: :all)
  end

  context "switched off" do
    before { stub_const("Integrations::Turnstile::ENABLED", false) }

    it "renders nothing" do
      visit("#{base_path}already_risky")

      expect(page).to have_no_css(".cf-turnstile", visible: :all)
    end
  end
end
