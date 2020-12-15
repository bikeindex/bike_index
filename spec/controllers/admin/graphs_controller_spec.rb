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
    context "kind" do
      it "renders" do
        get :index, params: {kind: "users"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
      it "renders" do
        get :index, params: {kind: "payments"}
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
        get :variable, params: {kind: "users", timezone: "America/Los_Angeles"}
        expect(response.status).to eq(200)
        expect(json_result.is_a?(Array)).to be_truthy
        expect(assigns(:start_time)).to be_within(1.day).of earliest_time
        expect(assigns(:end_time)).to be_within(1.minute).of Time.current
      end
      context "passed date and time" do
        let(:end_time) { "2019-01-22T13:48" }
        let(:start_time) { "2019-01-15T14:48" }
        it "returns json" do
          get :variable, params: {kind: "users", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
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
          get :variable, params: {kind: "payments", timezone: "America/Los_Angeles"}
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
            get :variable, params: {kind: "users", period: "custom", start_time: start_time, end_time: end_time, timezone: "America/Los_Angeles"}
            expect(response.status).to eq(200)
            expect(json_result.is_a?(Array)).to be_truthy
            Time.zone = TimeParser.parse_timezone("America/Los_Angeles")
            expect(assigns(:start_time).strftime("%Y-%m-%dT%H:%M")).to eq start_time
            expect(assigns(:end_time).strftime("%Y-%m-%dT%H:%M")).to eq end_time
          end
        end
      end
    end
  end

  # describe "users" do
  #   it "returns json" do
  #     get :users
  #     expect(response.status).to eq(200)
  #     result = JSON.parse(response.body)
  #     expect(result.keys.count).to be > 0
  #   end
  # end

  # describe "bikes" do
  #   context "no params" do
  #     it "returns JSON array" do
  #       get :bikes
  #       expect(response.status).to eq(200)
  #       result = JSON.parse(response.body)
  #       expect(result.is_a?(Array)).to be_truthy
  #       names = result.map { |r| r["name"] }
  #       expect(names.include?("Registrations")).to be_truthy
  #       expect(names.include?("Stolen")).to be_truthy
  #     end
  #   end
  #   context "start_time passed" do
  #     it "returns JSON array" do
  #       get :bikes, params: {start_time: "past_year"}
  #       expect(response.status).to eq(200)
  #       result = JSON.parse(response.body)
  #       expect(result.is_a?(Array)).to be_truthy
  #       names = result.map { |r| r["name"] }
  #       expect(names.include?("Registrations")).to be_truthy
  #       expect(names.include?("Stolen")).to be_truthy
  #     end
  #   end
  # end
end
