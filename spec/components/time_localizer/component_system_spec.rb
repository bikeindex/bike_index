# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeLocalizer::Component, :js, type: :system do
  let(:time_zone) { "America%2FChicago" }
  let(:page_url) { "time_localizer/component_preview/default?time_zone=#{time_zone}" }

  it "has the expected times" do
    visit(preview_path)

    expect(page).to have_content "A simple alert with some info"

    find('button[aria-label="Close"]').click

    expect(page).to_not have_content "a simple alert with some info"
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
