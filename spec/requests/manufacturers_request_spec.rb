require "rails_helper"

RSpec.describe ManufacturersController, type: :request do
  describe "index" do
    it "renders the index template with revised_layout" do
      get "/manufacturers"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
    context "with invalid UTF sequences" do
      # NOTE: This is the place that the rack-utf8_sanitizer gem is tested
      it "renders" do
        get "/manufacturers?%F6%22%6F%6E%6D%6F%75%73%65%6F%76%65%72%3D%67%36%59%4E%28%39%36%37%37%35%29%2F%2F"
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "tsv" do
    it "redirects to " do
      get "/manufacturers/tsv"
      expect(response).to redirect_to("https://files.bikeindex.org/uploads/tsvs/manufacturers.tsv")
    end
  end
end
