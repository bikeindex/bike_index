# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StravaRequestsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:strava_request) { FactoryBot.create(:strava_request) }

  base_url = "/admin/strava_requests"

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to eq([strava_request.id])
    end

    context "with render_chart" do
      it "renders chart including integration pie chart" do
        get base_url, params: {render_chart: true, period: "year"}
        expect(response.status).to eq(200)
        expect(response.body).to include("By integration")
      end

      context "with search_strava_integration_id" do
        it "does not render integration pie chart" do
          get base_url, params: {render_chart: true, period: "year", search_strava_integration_id: strava_request.strava_integration_id}
          expect(response.status).to eq(200)
          expect(response.body).not_to include("By integration")
        end
      end
    end
  end
end

RSpec.describe Admin::ChartStravaRequests::Component do
  describe "integration_counts" do
    let(:strava_integration) { FactoryBot.create(:strava_integration) }
    let(:time_range) { 1.week.ago..Time.current }
    let!(:strava_request) { FactoryBot.create(:strava_request, strava_integration:) }

    it "labels with integration id and user email" do
      component = described_class.new(collection: StravaRequest.all, time_range:)
      result = component.send(:integration_counts)
      expect(result.keys.first).to eq("#{strava_integration.user.email} (id: #{strava_integration.id})")
      expect(result.values.first).to eq(1)
    end

    context "when user is deleted" do
      it "labels with 'user deleted'" do
        strava_integration.user.destroy
        component = described_class.new(collection: StravaRequest.all, time_range:)
        result = component.send(:integration_counts)
        expect(result.keys.first).to eq("user deleted (id: #{strava_integration.id})")
      end
    end
  end
end
