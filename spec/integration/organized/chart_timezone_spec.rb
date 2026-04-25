# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Chart timezone", :js, type: :system do
  let(:enabled_feature_slugs) { %w[show_bulk_import] }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:, created_at: 5.years.ago) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let(:bulk_imports_path) { "/o/#{organization.to_param}/bulk_imports?render_chart=true&period=month" }

  # 5 AM UTC = 9 PM PST the previous day, so PST groups under one day and UTC under the next
  let(:created_at_utc) { 14.days.ago.utc.beginning_of_day + 5.hours }
  let!(:bulk_import) { FactoryBot.create(:bulk_import, organization:, created_at: created_at_utc) }
  let(:utc_date_key) { created_at_utc.strftime("%Y-%-m-%-d") }
  let(:la_date_key) { created_at_utc.in_time_zone("America/Los_Angeles").strftime("%Y-%-m-%-d") }

  before do
    visit new_session_path
    # Override browser timezone via Chrome DevTools Protocol
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "America/Los_Angeles")
    fill_in "Email", with: user.email
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  it "sets timezone cookie from browser and uses it for chart bucketing" do
    expect(la_date_key).not_to eq(utc_date_key)

    # First visit: no cookie yet, but JS runs and sets it from window.localTimezone
    visit bulk_imports_path
    expect(page).to have_css("table", wait: 5)

    cookie = page.driver.browser.manage.cookie_named("timezone")
    expect(cookie[:value]).to eq("America/Los_Angeles")

    # Reload so server reads the cookie and groups chart data in PST
    visit bulk_imports_path
    expect(page).to have_css("table", wait: 5)

    # Chart data is rendered inline as Chartkick init array tuples. The bucket
    # with the bulk import has count 1; days on either side have count 0.
    expect(page.html).to include(%(["#{la_date_key}",1]))
    expect(page.html).to include(%(["#{utc_date_key}",0]))
  end
end
