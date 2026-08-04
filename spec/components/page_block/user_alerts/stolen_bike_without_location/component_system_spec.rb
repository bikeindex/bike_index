# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::UserAlerts::StolenBikeWithoutLocation::Component, :js, type: :system do
  let(:preview_path) do
    "/rails/view_components/page_block/user_alerts/wrapper/component/stolen_bike_without_location"
  end

  it "leaves the banner behind when the modal is dismissed, and reopens it from there" do
    visit preview_path

    expect(page).to have_css("dialog#stolen-missing-location[open]", wait: 10)

    page.send_keys(:escape)

    expect(page).to have_no_css("dialog#stolen-missing-location[open]")
    expect(page).to have_content("Your stolen bike is missing its theft location!")

    click_link "add the theft location"

    expect(page).to have_css("dialog#stolen-missing-location[open]")
  end
end
