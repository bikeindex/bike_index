require "rails_helper"

base_url = "/api/v1/wheel_sizes"
RSpec.describe API::V1::WheelSizesController, type: :request do
  describe "index" do
    it "loads the request" do
      FactoryBot.create(:wheel_size)
      get base_url, headers: {format: :json}
      expect(response.code).to eq("200")
      expect(response.media_type).to eq "application/json"
    end
  end
end
