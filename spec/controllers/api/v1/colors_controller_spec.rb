require "rails_helper"

RSpec.describe Api::V1::ColorsController, type: :controller do
  describe "index" do
    it "loads the page" do
      FactoryBot.create(:color)
      get :index, format: :json
      expect(response.code).to eq("200")
    end
  end
end
