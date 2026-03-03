# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ChartStravaRequests::Component, type: :component do
  let(:time_range) { 1.week.ago..Time.current }
  let(:time_range_column) { "created_at" }
  let(:instance) { described_class.new(collection:, time_range:, time_range_column:) }
  let(:collection) { StravaRequest.where(time_range_column => time_range) }
  let!(:strava_integration) { FactoryBot.create(:strava_integration) }
  let!(:strava_request) do
    FactoryBot.create(:strava_request, :processed, strava_integration:)
  end

  it "renders both charts" do
    component = render_inline(instance)
    expect(component.text).to include("By response status")
    expect(component.text).to include("By request type")
  end

  context "with requested_at time_range_column" do
    let(:time_range_column) { "requested_at" }
    let!(:strava_request) do
      FactoryBot.create(:strava_request, :processed, strava_integration:, requested_at: 2.days.ago)
    end

    it "groups by requested_at" do
      expect(UI::Chart::Component).to receive(:time_range_counts)
        .with(hash_including(column: "requested_at")).twice.and_call_original
      render_inline(instance)
    end
  end
end
