# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ChartStravaRequests::Component, type: :component do
  let(:time_range) { 1.week.ago..Time.current }
  let(:instance) { described_class.new(collection:, time_range:) }
  let(:collection) { StravaRequest.where(created_at: time_range) }

  context "with requests" do
    let!(:strava_integration) { FactoryBot.create(:strava_integration) }
    let!(:request) do
      FactoryBot.create(:strava_request, :processed, strava_integration:)
    end

    it "renders both charts" do
      component = render_inline(instance)
      expect(component.text).to include("By response status")
      expect(component.text).to include("By request type")
    end
  end
end
