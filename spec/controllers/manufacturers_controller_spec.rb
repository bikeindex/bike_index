require "spec_helper"

describe ManufacturersController do
  describe "index" do
    it "renders with revised_layout" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
  describe "tsv" do
    before do
      get :tsv
    end
  end
end
