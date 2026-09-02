# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::UserAlerts::StolenBikeWithoutLocation::Component, :js, type: :system do
  let(:preview_path) do
    "/rails/view_components/shared_blocks/user_alerts/wrapper/component/stolen_bike_without_location"
  end

  it "leaves the whole prompt behind when the modal is dismissed" do
    visit preview_path

    expect(page).to have_css("dialog#stolen-missing-location[open]", wait: 10)

    page.send_keys(:escape)

    expect(page).to have_no_css("dialog#stolen-missing-location[open]")
    # Everything the modal said, still on the page - not a link back to it
    expect(page).to have_content("Please add theft location")
    expect(page).to have_content("It is critical for recovery")
    expect(page).to have_link("Add the location of the theft of your 2018 Surly Cross Check",
      href: "/bikes/12/edit/theft_details#where-theft-happened")
    expect(page).to have_content("Without a location we can't spread the word")
  end
end
