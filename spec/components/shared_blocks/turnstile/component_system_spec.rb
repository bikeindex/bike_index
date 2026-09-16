# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Turnstile::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/shared_blocks/turnstile/component/" }

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

  it "renders the widget shown when the address was already submitted" do
    visit("#{base_path}already_risky")

    expect(page).to have_css(".cf-turnstile")
  end

  it "renders nothing without keys" do
    visit("#{base_path}without_keys")

    expect(page).to have_no_css(".cf-turnstile", visible: :all)
  end
end
