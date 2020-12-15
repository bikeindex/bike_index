require "rails_helper"

RSpec.describe Admin::GraphsController, type: :controller do
  include_context :logged_in_as_super_admin
  describe "index" do
    context "graphs" do
      it "renders" do
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "users" do
      it "renders" do
        get :index, params: {search_kind: "users"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "payments" do
      it "renders" do
        get :index, params: {search_kind: "payments"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "bikes" do
      it "renders" do
        get :index, params: {search_kind: "bikes"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "tables" do
    it "renders" do
      get :tables
      expect(response.status).to eq(200)
      expect(response).to render_template(:tables)
    end
  end

  describe "variable" do
    let(:earliest_time) { Time.at(1134972000) } # earliest_period_date
    it "returns json" do
      get :variable
      expect(response.status).to eq(200)
      expect(json_result["error"]).to be_present # Because kind is general, which doesn't get a graph
    end
    context "users" do
      it "returns json" do
        get :variable, params: {search_kind: "users", timezone: "America/Los_Angeles"}
        expect(response.status).to eq(200)
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:start_time)).to be_within(1.day).of earliest_time
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
      end
      context "passed date and time" do
        let(:end_time) { "2019-01-22T13:48" }
        let(:start_time) { "2019-01-15T14:48" }
        it "returns json" do
          get :variable, params: {search_kind: "users", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
          expect(response.status).to eq(200)
          expect(json_result.is_a?(Array)).to be_truthy
          Time.zone = TimeParser.parse_timezone("America/Los_Angeles")
          expect(assigns(:start_time).strftime("%Y-%m-%dT%H:%M")).to eq start_time
          expect(assigns(:end_time).strftime("%Y-%m-%dT%H:%M")).to eq end_time
        end
      end
      context "payments" do
        let!(:payment) { FactoryBot.create(:payment) }
        it "returns json" do
          get :variable, params: {search_kind: "payments", timezone: "America/Los_Angeles"}
          expect(response.status).to eq(200)
          json_result.each do |data_group|
            expect(data_group.keys.count).to be > 0
            expect(data_group.keys.first.class).to eq(String)
            expect(data_group.values.first.class).to eq(String)
            expect(data_group["error"]).to_not be_present
          end
          expect(assigns(:start_time)).to be_within(1.day).of earliest_time
          expect(assigns(:end_time)).to be_within(1.minute).of Time.current
        end
        context "passed date and time" do
          let(:end_time) { "2019-01-22T13:48" }
          let(:start_time) { "2019-01-15T14:48" }
          it "returns json" do
            get :variable, params: {search_kind: "users", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
            expect(response.status).to eq(200)
            expect(json_result.is_a?(Array)).to be_truthy
            Time.zone = TimeParser.parse_timezone("America/Los_Angeles")
            expect(assigns(:start_time).strftime("%Y-%m-%dT%H:%M")).to eq start_time
            expect(assigns(:end_time).strftime("%Y-%m-%dT%H:%M")).to eq end_time
          end
        end
      end
    end
    context "bikes" do
      it "returns json" do
        get :variable, params: {search_kind: "bikes", timezone: "America/Los_Angeles"}
        expect(response.status).to eq(200)
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:start_time)).to be_within(1.day).of earliest_time
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
        expect(assigns(:bike_graph_kind)).to eq "stolen"
        # And it gets the other kinds too
        get :variable, params: {search_kind: "bikes", timezone: "America/Los_Angeles", bike_graph_kind: "origin"}
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:bike_graph_kind)).to eq "origin"
        get :variable, params: {search_kind: "bikes", timezone: "America/Los_Angeles", bike_graph_kind: "pos"}
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:bike_graph_kind)).to eq "pos"
      end
    end
  end
end
