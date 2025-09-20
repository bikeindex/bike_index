require "rails_helper"

base_url = "/admin/graphs"
RSpec.describe Admin::GraphsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  describe "index" do
    context "graphs" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "users" do
      it "renders" do
        get base_url, params: {search_kind: "users"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "recoveries" do
      it "renders" do
        get base_url, params: {search_kind: "recoveries"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "bikes" do
      it "renders" do
        get base_url, params: {search_kind: "bikes"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "tables" do
    it "renders" do
      get "#{base_url}/tables"
      expect(response.status).to eq(200)
      expect(response).to render_template(:tables)
      get "#{base_url}/tables", params: {location: "San Francisco, CA"}
      expect(response.status).to eq(200)
      expect(response).to render_template(:tables)
    end
  end

  describe "variable" do
    let(:earliest_time) { Time.at(1134972000) } # earliest_period_date
    it "returns json" do
      get "#{base_url}/variable"
      expect(response.status).to eq(200)
      expect(json_result["error"]).to be_present # Because kind is general, which doesn't get a graph
    end
    context "users" do
      it "returns json" do
        get "#{base_url}/variable", params: {search_kind: "users", timezone: "America/Los_Angeles", period: "all"}
        expect(response.status).to eq(200)
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:start_time)).to be_within(1.day).of earliest_time
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
      end

      context "passed date and time" do
        let(:end_time) { "2019-01-22T13:48" }
        let(:start_time) { "2019-01-15T14:48" }
        it "returns json" do
          get "#{base_url}/variable", params: {search_kind: "users", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
          expect(response.status).to eq(200)
          expect(json_result.is_a?(Array)).to be_truthy
          Time.zone = TimeZoneParser.parse("America/Los_Angeles")
          expect(assigns(:start_time).strftime("%Y-%m-%dT%H:%M")).to eq start_time
          expect(assigns(:end_time).strftime("%Y-%m-%dT%H:%M")).to eq end_time
        end
      end
    end
    context "recoveries" do
      let!(:payment) { FactoryBot.create(:payment) }
      it "returns json" do
        get "#{base_url}/variable", params: {search_kind: "recoveries", timezone: "America/Los_Angeles"}
        expect(response.status).to eq(200)
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:start_time)).to be_within(1.day).of(Time.current - 1.year)
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
      end
      context "passed date and time" do
        let(:end_time) { "2019-01-22T13:48" }
        let(:start_time) { "2019-01-15T14:48" }
        it "returns json" do
          get "#{base_url}/variable", params: {search_kind: "recoveries", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
          expect(response.status).to eq(200)
          expect(json_result.is_a?(Array)).to be_truthy
          Time.zone = TimeZoneParser.parse("America/Los_Angeles")
          expect(assigns(:start_time).strftime("%Y-%m-%dT%H:%M")).to eq start_time
          expect(assigns(:end_time).strftime("%Y-%m-%dT%H:%M")).to eq end_time
        end
      end
    end
    context "bikes" do
      it "returns json" do
        get "#{base_url}/variable", params: {search_kind: "bikes", timezone: "America/Los_Angeles"}
        expect(response.status).to eq(200)
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:start_time)).to be_within(1.day).of(Time.current - 1.year)
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
        # And it gets the other kinds too
        get "#{base_url}/variable", params: {search_kind: "bikes", timezone: "America/Los_Angeles", bike_graph_kind: "origin"}
        expect(json_result.is_a?(Array)).to be_truthy
        get "#{base_url}/variable", params: {search_kind: "bikes", timezone: "America/Los_Angeles", bike_graph_kind: "pos"}
        expect(json_result.is_a?(Array)).to be_truthy
      end
    end
  end
end
