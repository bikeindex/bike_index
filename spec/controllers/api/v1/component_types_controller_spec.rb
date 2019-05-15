require "spec_helper"

describe Api::V1::ComponentTypesController do
  describe "index" do
    it "loads the request" do
      FactoryBot.create(:ctype)
      get :index, format: :json
      expect(response.code).to eq("200")
    end
  end
end
