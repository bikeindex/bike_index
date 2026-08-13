require "rails_helper"

RSpec.describe StolenController, type: :request do
  describe "index" do
    it "renders with layout even if text" do
      get "/stolen.txt"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "faq" do
    it "redirects other pages to index" do
      get "/stolen/faq"
      expect(response).to redirect_to stolen_index_url
    end
  end

  # The vendored multi_serial_search bundle hardcodes this webpacker path for the
  # search button's icon, and renders a broken image without it
  describe "the bundle's icon path" do
    it "redirects to the asset" do
      get "/packs/media/stolen/search-583a6c1f.svg"
      expect(response).to redirect_to(%r{/assets/stolen/search-\w+\.svg})
    end
  end

  describe "current_tsv" do
    it "redirects to current_tsv" do
      get "/stolen/current_tsv"
      expect(response).to redirect_to StolenController::CURRENT_TSV_URL

      get "/stolen/current_tsv_rapid"
      expect(response).to redirect_to StolenController::CURRENT_TSV_URL
    end
  end
end
