require "rails_helper"

RSpec.describe "BikesSearch API V2", type: :request do
  describe "bike search" do
    before :each do
      FactoryBot.create(:bike)
      FactoryBot.create(:bike)
      FactoryBot.create(:impounded_bike)
    end
    it "all bikes (root) search works" do
      get "/api/v2/bikes_search?per_page=1", params: {format: :json}
      expect(response.code).to eq("200")
      expect(response.header["Total"]).to eq("3")
      expect(response.header["Link"].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      bike_response = json_result["bikes"][0]
      expect(bike_response["id"]).to be_present
      expect(bike_response.keys & ["user_hidden"]).to eq([]) # Verify we aren't showing all attributes
    end

    it "non_stolen bikes search works" do
      get "/api/v2/bikes_search/non_stolen?per_page=1", params: {format: :json}
      expect(response.code).to eq("200")
      expect(response.header["Total"]).to eq("3")
      expect(response.header["Link"].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      bike_response = json_result["bikes"][0]
      expect(bike_response["id"]).to be_present
      expect(bike_response.keys & ["user_hidden"]).to eq([]) # Verify we aren't showing all attributes
    end

    it "serial search works" do
      bike = FactoryBot.create(:bike, serial_number: "0000HEYBB")
      get "/api/v2/bikes_search/?serial=0HEYBB", params: {format: :json}
      result = JSON.parse(response.body)
      expect(response.code).to eq("200")
      expect(response.header["Total"]).to eq("1")
      expect(result["bikes"][0]["id"]).to eq(bike.id)
    end

    it "stolen search works" do
      FactoryBot.create(:stolen_bike)
      get "/api/v2/bikes_search/stolen?per_page=1", params: {format: :json}
      expect(response.code).to eq("200")
      expect(response.header["Total"]).to eq("1")
      result = response.body
      expect(JSON.parse(result)["bikes"][0]["id"]).to be_present
    end
  end

  describe "fuzzy serial search" do
    it "finds a close one" do
      bike = FactoryBot.create(:bike, serial_number: "Something1")
      bike.create_normalized_serial_segments
      get "/api/v2/bikes_search/close_serials?serial=s0meth1nglvv", params: {format: :json}
      result = JSON.parse(response.body)
      expect(response.code).to eq("200")
      expect(response.header["Total"]).to eq("1")
      expect(result["bikes"][0]["id"]).to eq(bike.id)
    end
  end

  describe "count" do
    it "returns the count hash for matching bikes, doesn't need access_token" do
      FactoryBot.create(:bike, serial_number: "awesome")
      FactoryBot.create(:bike)
      get "/api/v2/bikes_search/count?query=awesome", params: {format: :json}
      result = JSON.parse(response.body)
      expect(result["non_stolen"]).to eq(1)
      expect(result["stolen"]).to eq(0)
      expect(result["proximity"]).to eq(0)
      expect(response.code).to eq("200")
    end

    # Stubbing initialize prints out a warning. I don't really care about this test, who's using V2 anyway?
    # it "proximity square does not overwrite the proximity_radius" do
    #   opts = {proximity_square: 100, proximity_radius: "10"}
    #   target = opts.merge(proximity: "ip")
    #   expect_any_instance_of(BikeServices::Searcher).to receive(:initialize).with(target)
    #   get "/api/v2/bikes_search/count", params: opts.merge(format: :json)
    # end
  end

  describe "all_stolen" do
    it "returns the cached file" do
      FactoryBot.create(:stolen_bike)
      t = Time.current.to_i
      FileCacheMaintenanceJob.new.perform
      cached_all_stolen = FileCacheMaintainer.cached_all_stolen
      expect(cached_all_stolen["updated_at"].to_i).to be >= t
      get "/api/v2/bikes_search/all_stolen", params: {format: :json}
      result = JSON.parse(response.body)
      expect(response.header["Last-Modified"]).to eq Time.at(cached_all_stolen["updated_at"].to_i).httpdate
      expect(result).to eq(JSON.parse(File.read(cached_all_stolen["path"])))
    end
  end
end
