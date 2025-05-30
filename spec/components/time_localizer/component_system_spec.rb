# frozen_string_literal: true

require "rails_helper"

RSpec.describe "time_localizer.js", :js, type: :system do
  let(:time_zone) { "America/Chicago" }
  let(:preview_path) { "/rails/view_components/time_localizer/component/default?time_zone=#{CGI.escape(time_zone)}" }
  let(:current_in_zone) { TimeParser.parse(Time.current, time_zone, in_time_zone: true) }

  it "has the expected times" do
    visit(preview_path)

    expect(page).to have_content("Current time: #{current_in_zone.strftime("%l:%M %p")}", wait: 5)

    expect(page).to have_content("Yesterday: #{(current_in_zone - 1.day).strftime("%B %e")}")
    expect(page).to have_content("Tomorrow: #{(current_in_zone + 1.day).strftime("%B %e")}")
    expect(page).to have_content("One week ago: #{(current_in_zone - 7.days).strftime("%B %e")}")
    expect(page).to have_content("One year ago: #{(current_in_zone - 1.year).strftime("%B %e, %Y")}")

    expect(page).to have_content("Yesterday (precise time): #{(current_in_zone - 1.day).strftime("%B %e, %l:%M %p")}")
    expect(page).to have_content("One year ago (precise time seconds): #{(current_in_zone - 1.year).strftime("%B %-e, %Y, %-l:%M:%S %p")}")
  end
end
