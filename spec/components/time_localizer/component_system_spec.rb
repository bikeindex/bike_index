# frozen_string_literal: true

require "rails_helper"

RSpec.describe "time_localizer.js", :js, type: :system do
  let(:time_zone) { "America/Chicago" }
  let(:preview_path) { "/rails/view_components/time_localizer/component/default?time_zone=#{CGI.escape(time_zone)}" }
  let(:current_in_zone) { TimeParser.parse(Time.current, time_zone, in_time_zone: true) }

  it "has the expected times" do
    visit(preview_path)

    sleep 1 # WTF, TimeLocalizer isn't executing before running the spec
    expect(page).to have_content("Current time: #{current_in_zone.strftime("%l:%M %p")}", wait: 10)
  end

  # describe 'localizedTimeHtml method' do
  #   it 'returns HTML string with localized time' do
  #     result = page.evaluate_script(<<~JS)
  #       window.timeLocalizer.localizedTimeHtml('#{unix_timestamp}', {})
  #     JS

  #     expect(result).to include('<span')
  #     expect(result).to include('title=')
  #     expect(result).to include('Nov')
  #   end

  #   it 'handles options for precise time' do
  #     result = page.evaluate_script(<<~JS)
  #       window.timeLocalizer.localizedTimeHtml('#{unix_timestamp}', {
  #         preciseTime: true,
  #         includeSeconds: true
  #       })
  #     JS

  #     expect(result).to include('<small>')
  #     expect(result).to match(/\d{1,2}:\d{2}/)
  #   end

  #   it 'handles withPreposition option' do
  #     result = page.evaluate_script(<<~JS)
  #       window.timeLocalizer.localizedTimeHtml('#{unix_timestamp}', {
  #         preciseTime: true,
  #         withPreposition: true
  #       })
  #     JS

  #     expect(result).to include(' at ')
  #   end

  #   it 'returns empty span for invalid time' do
  #     result = page.evaluate_script(<<~JS)
  #       window.timeLocalizer.localizedTimeHtml('invalid-time', {})
  #     JS

  #     expect(result).to eq('<span></span>')
  #   end
  # end
end
