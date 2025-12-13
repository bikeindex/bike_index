# frozen_string_literal: true

require "rails_helper"

RSpec.describe "time_localizer.js", :js, type: :system do
  let(:time_zone) { "America/Chicago" }
  let(:preview_path) { "/rails/view_components/time_localizer/component/default?time_zone=#{CGI.escape(time_zone)}" }
  let(:current_time_in_zone) { Binxtils::TimeParser.parse(Time.current, time_zone, in_time_zone: true) }

  def regex_time_match(str)
    formatted = str.strip.gsub("  ", " ") # required because dumb spaces in strftime
      .gsub(/ (am|pm)\z/i) { |m| m.downcase.strip } # lowercase am and pm and remove leading space
    pp formatted
    Regexp.escape(formatted).gsub(/(\d)(am|pm)\z/i, '\d\2')
  end

  # Flaky because time changes
  it "has the expected times", :flaky do
    visit(preview_path)
    # Put all the parsing up here so that the time is less likely to have changed (to reduce flakiness)
    current_in_zone = current_time_in_zone
    # current_time = regex_time_match(current_in_zone.strftime("%l:%M %p"))
    # yesterday = regex_time_match((current_in_zone - 1.day).strftime("%b %e"))
    # tomorrow = regex_time_match((current_in_zone + 1.day).strftime("%b %e"))
    # one_week_ago = regex_time_match((current_in_zone - 7.days).strftime("%b %e"))
    # one_year_ago = regex_time_match((current_in_zone - 1.year).strftime("%b %e, %Y"))
    # yesterday_precise = regex_time_match((current_in_zone - 1.day).strftime("%b %e, %l:%M %p")).gsub("  ", " ")
    one_year_ago_precise = regex_time_match((current_in_zone - 1.year).strftime("%b %-e, %Y, %-l:%M:%S %p"))
    pp one_year_ago_precise

    expect(page).to have_content(/Current time: #{current_time}/, wait: 5)
    expect(page).to have_content(/Yesterday: #{yesterday}/)
    expect(page).to have_content(/Tomorrow: #{tomorrow}/)
    expect(page).to have_content(/One week ago: #{one_week_ago}/)
    expect(page).to have_content(/One year ago: #{one_year_ago}/)
    expect(page).to have_content(/Yesterday (precise time): #{yesterday_precise}/)
    expect(page).to have_content(/One year ago (precise time seconds): #{one_year_ago_precise}/)
  end
end
