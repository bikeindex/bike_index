require "rails_helper"

RSpec.describe Api::V1::WheelSizesController, type: :controller do
  describe "index" do
    it "loads the request" do
      FactoryBot.create(:wheel_size)
      get :index, format: :json
      expect(response.code).to eq("200")
    end
  end
end
