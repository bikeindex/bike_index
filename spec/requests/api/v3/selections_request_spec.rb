require "rails_helper"

RSpec.describe "Selections API V3", type: :request do
  describe "colors" do
    let!(:color) { FactoryBot.create(:color, display: "#386ed2") }
    let(:target) { {name: color.name, hex_code: "#386ed2", slug: color.slug, id: color.id} }
    it "responds on index" do
      get "/api/v3/selections/colors"
      expect(response.code).to eq("200")
      expect(json_result["colors"][0]).to match_hash_indifferently target
    end
  end

  describe "component_types" do
    it "responds on index with pagination" do
      expect(Ctype.other).to be_present
      selection = FactoryBot.create(:ctype)
      expect(Ctype.count).to eq 2
      get "/api/v3/selections/component_types"
      expect(response.code).to eq("200")
      response_names = json_result["component_types"].map { _1["name"] }
      expect(response_names.sort).to eq([selection.name, "unknown"])
    end
  end

  describe "cycle_types" do
    it "responds on index with pagination" do
      selection = CycleType.legacy_selections[0]
      get "/api/v3/selections/cycle_types"
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)["cycle_types"][0]
      expect(result["name"]).to eq(selection[:name])
    end
  end

  describe "frame_materials" do
    it "responds on index with pagination" do
      get "/api/v3/selections/frame_materials"
      selection = FrameMaterial.legacy_selections[0]
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)["frame_materials"][0]
      expect(result["name"]).to eq(selection[:name])
    end
  end

  describe "front_gear_types" do
    it "responds on index with pagination" do
      selection = FactoryBot.create(:front_gear_type)
      get "/api/v3/selections/front_gear_types"
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)["front_gear_types"][0]
      expect(result["name"]).to eq(selection.name)
    end
  end

  describe "rear_gear_types" do
    it "responds on index with pagination" do
      selection = FactoryBot.create(:rear_gear_type)
      get "/api/v3/selections/rear_gear_types"
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)["rear_gear_types"][0]
      expect(result["name"]).to eq(selection.name)
    end
  end

  describe "handlebar_types" do
    it "responds on index with pagination" do
      selection = HandlebarType.legacy_selections[0]
      get "/api/v3/selections/handlebar_types"
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)["handlebar_types"][0]
      expect(result["name"]).to eq(selection[:name])
    end
  end

  describe "propulsion_types" do
    it "responds on index with pagination" do
      selection = PropulsionType.legacy_selections[0]
      get "/api/v3/selections/propulsion_types"
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)["propulsion_types"][0]
      expect(result["name"]).to eq(selection[:name])
    end
  end

  describe "wheel_size" do
    it "responds on index with pagination" do
      wheel_size = FactoryBot.create(:wheel_size)
      FactoryBot.create(:wheel_size)
      get "/api/v3/selections/wheel_sizes?per_page=1"
      expect(response.header["Total"]).to eq("2")
      pagination_link = '<http://www.example.com/api/v3/selections/wheel_sizes?page=2&per_page=1>; rel="last", <http://www.example.com/api/v3/selections/wheel_sizes?page=2&per_page=1>; rel="next"'
      expect(response.header["Link"]).to eq(pagination_link)
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)["wheel_sizes"][0]
      expect(result["iso_bsd"]).to eq(wheel_size.iso_bsd)
      expect(result["popularity"]).to eq(wheel_size.popularity)
    end
  end
end
