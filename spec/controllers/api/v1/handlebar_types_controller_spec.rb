require "rails_helper"

RSpec.describe API::V1::HandlebarTypesController, type: :controller do
  describe "index" do
    it "loads the page" do
      get :index, format: :json
      expect(response.code).to eq("200")
    end
  end
end
