require "rails_helper"

base_url = "/api/v1/frame_materials"
RSpec.describe API::V1::FrameMaterialsController, type: :request do
  describe "index" do
    it "loads the page" do
      get base_url, headers: {format: :json}
      expect(response.code).to eq("200")
    end
  end
end
