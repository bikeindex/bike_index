require 'spec_helper'

describe Admin::GraphsController, type: :controller do
  include_context :logged_in_as_super_admin
  describe 'index' do
    context 'graphs' do
      it 'renders' do
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context "kind" do
      it "renders" do
        get :index, kind: "users"
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end

  describe 'tables' do
    it 'renders' do
      get :tables
      expect(response.status).to eq(200)
      expect(response).to render_template(:tables)
    end
  end

  describe "variable" do
    it "returns json" do
      get :variable
      expect(response.status).to eq(200)
      json_result = JSON.parse(response.body)
      expect(json_result["error"]).to be_present # Because kind is general, which doesn't get a graph
    end
    context "users" do
      it "returns json" do
        get :variable, kind: "users", timezone: "America/Los_Angeles"
        expect(response.status).to eq(200)
        json_result = JSON.parse(response.body)
        expect(json_result["error"]).to_not be_present
        expect(json_result.keys.count).to be > 0
        expect(assigns(:start_at)).to be_within(1.day).of Time.parse("2007-01-01 1:00")
        expect(assigns(:end_at)).to be_within(1.minute).of Time.now
        expect(assigns(:group_period)).to eq "month"
      end
      context "passed date and time" do
        let(:end_at) { "2019-01-22T13:48" }
        let(:start_at) { "2019-01-15T14:48" }
        it "returns json" do
          get :variable, kind: "users", start_at: start_at,
                         end_at: end_at, timezone: "America/Los_Angeles"
          expect(response.status).to eq(200)
          json_result = JSON.parse(response.body)
          expect(json_result.keys.count).to be > 0
          Time.zone = TimeParser.parse_timezone("America/Los_Angeles")
          expect(assigns(:start_at).strftime("%Y-%m-%dT%H:%M")).to eq start_at
          expect(assigns(:end_at).strftime("%Y-%m-%dT%H:%M")).to eq end_at
          expect(assigns(:group_period)).to eq "day"
        end
      end
    end
  end

  describe 'users' do
    it 'returns json' do
      get :users
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result.keys.count).to be > 0
    end
  end

  describe 'bikes' do
    context 'no params' do
      it 'returns JSON array' do
        get :bikes
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result.is_a?(Array)).to be_truthy
        names = result.map { |r| r['name'] }
        expect(names.include?('Registrations')).to be_truthy
        expect(names.include?('Stolen')).to be_truthy
      end
    end
    context 'start_at passed' do
      it 'returns JSON array' do
        get :bikes, start_at: 'past_year'
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result.is_a?(Array)).to be_truthy
        names = result.map { |r| r['name'] }
        expect(names.include?('Registrations')).to be_truthy
        expect(names.include?('Stolen')).to be_truthy
      end
    end
  end
end
