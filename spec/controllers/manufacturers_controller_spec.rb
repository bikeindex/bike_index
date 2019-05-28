require "spec_helper"

describe ManufacturersController do
  describe "index" do
    it "renders the index template with revised_layout" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "tsv" do
    it "redirects to " do
      get :tsv
      expect(response).to redirect_to("https://files.bikeindex.org/uploads/tsvs/manufacturers.tsv")
    end
  end
end
