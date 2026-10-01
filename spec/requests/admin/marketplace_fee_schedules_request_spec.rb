# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::MarketplaceFeeSchedulesController, type: :request do
  let(:base_url) { "/admin/marketplace_fee_schedules" }
  let(:timezone) { "America/Los_Angeles" }
  let(:future_start) { 2.days.from_now.in_time_zone(timezone).change(sec: 0) }
  let(:attrs) { {platform_fee_percent: 12.5, platform_fee_cap: 69.29, processing_fee_percent: 2, start_at: future_start.strftime("%Y-%m-%dT%H:%M")} }

  def page = Capybara.string(response.body)

  context "when not a superuser" do
    include_context :request_spec_logged_in_as_user

    it "refuses" do
      get base_url
      expect(response).to redirect_to(user_root_url)
      expect(flash[:error]).to be_present

      post base_url, params: {marketplace_fee_schedule: attrs, timezone:}
      expect(response).to redirect_to(user_root_url)
      expect(MarketplaceFeeSchedule.count).to eq 0
    end
  end

  context "when a superuser" do
    include_context :request_spec_logged_in_as_superuser

    let(:started) { FactoryBot.create(:marketplace_fee_schedule, :started, platform_fee_percent: 10, platform_fee_cap_cents: 75_50) }
    let(:upcoming) { FactoryBot.create(:marketplace_fee_schedule) }

    it "lists every schedule, marking the one in effect and the upcoming one" do
      FactoryBot.create(:marketplace_fee_schedule, :started, start_at: 2.years.ago)
      started
      upcoming
      get base_url
      expect(response).to render_template(:index)
      expect(page).to have_link("New fee schedule", href: "#{base_url}/new")
      # newest start_at first, so the in effect row is the middle one
      expect(page.all("tbody tr").map { |row| [row.has_text?("In effect now"), row.has_text?("Upcoming"), row.has_text?("$75.50")] })
        .to eq([[false, true, false], [true, false, true], [false, false, false]])
      expect(page).to have_link("Edit", href: "#{base_url}/#{upcoming.id}/edit", count: 1)
      expect(page).to have_link("Delete", count: 1)
    end

    it "pre-fills the new form from the schedule in effect and leaves start_at blank" do
      started
      get "#{base_url}/new"
      expect(response).to render_template(:new)
      expect(page).to have_field("marketplace_fee_schedule[platform_fee_percent]", with: "10.0")
      expect(page).to have_field("marketplace_fee_schedule[platform_fee_cap]", with: "75.5")
      expect(page).to have_field("marketplace_fee_schedule[processing_fee_percent]", with: "3.0")
      expect(page.find_field("marketplace_fee_schedule[start_at]").value).to be_blank
    end

    it "creates a schedule in the future, taking the cap in dollars and start_at in the browser's zone" do
      expect { post base_url, params: {marketplace_fee_schedule: attrs, timezone:} }.to change(MarketplaceFeeSchedule, :count).by(1)
      expect(response).to redirect_to(base_url)
      expect(flash[:success]).to be_present
      expect(MarketplaceFeeSchedule.last).to have_attributes(platform_fee_percent: 12.5, platform_fee_cap_cents: 69_29,
        processing_fee_percent: 2, start_at: future_start)
    end

    it "rejects a start_at in the past and saves nothing" do
      past_attrs = attrs.merge(start_at: 1.day.ago.in_time_zone(timezone).strftime("%Y-%m-%dT%H:%M"))
      expect { post base_url, params: {marketplace_fee_schedule: past_attrs, timezone:} }.to_not change(MarketplaceFeeSchedule, :count)
      expect(response.status).to eq 422
      expect(response).to render_template(:new)
      expect(page).to have_text("Start at must be in the future")
      expect(page).to have_field("marketplace_fee_schedule[platform_fee_cap]", with: "69.29")
    end

    it "edits, updates and destroys an upcoming schedule" do
      get "#{base_url}/#{upcoming.id}/edit"
      expect(response).to render_template(:edit)
      expect(page).to have_field("marketplace_fee_schedule[platform_fee_cap]", with: "69.0")

      patch "#{base_url}/#{upcoming.id}", params: {marketplace_fee_schedule: attrs, timezone:}
      expect(response).to redirect_to(base_url)
      expect(upcoming.reload).to have_attributes(platform_fee_percent: 12.5, platform_fee_cap_cents: 69_29, start_at: future_start)

      patch "#{base_url}/#{upcoming.id}", params: {marketplace_fee_schedule: {start_at: 1.hour.ago.iso8601}}
      expect(response.status).to eq 422
      expect(page).to have_text("Start at must be in the future")
      expect(upcoming.reload.start_at).to eq future_start

      expect { delete "#{base_url}/#{upcoming.id}" }.to change(MarketplaceFeeSchedule, :count).by(-1)
      expect(response).to redirect_to(base_url)
      expect(flash[:success]).to be_present
    end

    it "refuses to edit, update or destroy a started schedule" do
      original_attributes = started.reload.attributes
      [[:get, "#{base_url}/#{started.id}/edit"],
        [:patch, "#{base_url}/#{started.id}", {marketplace_fee_schedule: attrs, timezone:}],
        [:delete, "#{base_url}/#{started.id}"]].each do |verb, url, params|
        send(verb, url, params:)
        expect(response).to redirect_to(base_url)
        follow_redirect!
        expect(page).to have_text("already started")
      end

      expect(MarketplaceFeeSchedule.find(started.id).attributes).to eq original_attributes
    end
  end
end
