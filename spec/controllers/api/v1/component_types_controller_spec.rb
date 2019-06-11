require "rails_helper"

RSpec.describe Api::V1::ComponentTypesController, type: :controller do
  describe "index" do
    it "loads the request" do
      FactoryBot.create(:ctype)
      get :index, format: :json
      expect(response.code).to eq("200")
    end
  end
end
