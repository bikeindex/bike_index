# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Footer::Component, :js, type: :system do
  # Without a rate, rendering in euros redirects to the root url in the default locale
  before { FactoryBot.create(:exchange_rate_to_eur) }

  # The form carries no action, so the language has to land on the page the browser is on,
  # keeping the params it was reached with
  it "switches the language on the current page, and leaves the default language off the URL" do
    visit "/?example=1"
    wait_for_stimulus
    select "Nederlands (Dutch)", from: "locale"
    expect(page).to have_current_path("/?example=1&locale=nl")

    wait_for_stimulus
    select "English (Engels)", from: "locale"
    expect(page).to have_current_path("/?example=1")
  end

  # A Dutch browser renders Dutch with no param, so English is the language that needs one --
  # dropping it for the default would land this visitor back in Dutch
  context "with a browser asking for a non-default language" do
    before do
      page.driver.with_playwright_page do |playwright_page|
        playwright_page.context.set_extra_http_headers("Accept-Language" => "nl,en;q=0.9")
      end
    end

    it "adds the param for the default language" do
      visit "/?example=1"
      wait_for_stimulus
      select "English (Engels)", from: "locale"
      expect(page).to have_current_path("/?example=1&locale=en")
    end
  end
end
