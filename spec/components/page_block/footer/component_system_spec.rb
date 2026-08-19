# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Footer::Component, :js, type: :system do
  # Without a rate, rendering in euros redirects to the root url in the default locale
  before { FactoryBot.create(:exchange_rate_to_eur) }

  # The form carries no action, so the language has to land on the page the browser is on,
  # keeping the params it was reached with. Switching back names the language too, rather
  # than dropping the param -- a visitor whose browser asks for Dutch needs it to reach English
  it "switches the language on the current page, and back" do
    visit "/?example=1"
    wait_for_stimulus
    select "Nederlands (Dutch)", from: "locale"
    expect(page).to have_current_path("/?example=1&locale=nl")

    wait_for_stimulus
    select "English (Engels)", from: "locale"
    expect(page).to have_current_path("/?example=1&locale=en")
  end
end
