# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::UserAlerts::Wrapper::Component, :js, type: :system do
  # Text that only appears once that alert rendered, keyed by the preview scenario
  let(:alert_text) do
    {"phone_waiting_confirmation" => "Confirm your phone number",
     "stolen_bike_without_location" => "Please add theft location",
     "theft_alert_without_photo" => "Please add a photo",
     "unfinished_registration" => "isn't registered yet!"}
  end

  let(:preview_path) { "/rails/view_components/shared_blocks/user_alerts/wrapper/component" }

  it "renders the alert each scenario is named for, and none of the others" do
    expect(alert_text.keys.sort).to eq UserAlert.general_kinds.sort

    alert_text.each do |scenario, text|
      visit "#{preview_path}/#{scenario}"

      expect(page).to have_content(text)
      alert_text.except(scenario).each_value { |other| expect(page).to have_no_content(other) }
    end
  end
end
