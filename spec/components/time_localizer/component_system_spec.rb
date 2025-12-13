# frozen_string_literal: true

require "rails_helper"

RSpec.describe "time_localizer.js", :js, type: :system do
  let(:time_zone) { "America/Chicago" }
  let(:preview_path) { "/rails/view_components/time_localizer/component/default?time_zone=#{CGI.escape(time_zone)}" }
  let(:current_time_in_zone) { Binxtils::TimeParser.parse(Time.current, time_zone, in_time_zone: true) }

  def strip(str)
    str.strip.gsub("  ", " ") # required because dumb spaces in strftime
  end

  # Flaky because time changes
  it "has the expected times", :flaky do
    visit(preview_path)
    current_in_zone = current_time_in_zone

    expect(page).to have_content("Current time: #{strip(current_in_zone.strftime("%l:%M %p"))}", wait: 5)

    expect(page).to have_content("Yesterday: #{strip((current_in_zone - 1.day).strftime("%b %e"))}")
    expect(page).to have_content("Tomorrow: #{strip((current_in_zone + 1.day).strftime("%b %e"))}")
    expect(page).to have_content("One week ago: #{strip((current_in_zone - 7.days).strftime("%b %e"))}")
    expect(page).to have_content("One year ago: #{strip((current_in_zone - 1.year).strftime("%b %e, %Y"))}")

    expect(page).to have_content("Yesterday (precise time): #{strip((current_in_zone - 1.day).strftime("%b %e, %l:%M %p")).gsub("  ", " ")}")
    expect(page).to have_content("One year ago (precise time seconds): #{strip((current_in_zone - 1.year).strftime("%b %-e, %Y, %-l:%M:%S %p"))}")
  end
end
