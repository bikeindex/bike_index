require "rails_helper"

RSpec.describe StolenController, type: :request do
  describe "index" do
    let!(:recovery_display) { FactoryBot.create(:recovery_display, quote: "Found it on my alert", quote_by: "Sandy") }

    it "renders with layout even if text" do
      get "/stolen.txt"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq "text/html"
      expect(response.body).to match("Your bike is gone.")
      expect(response.body).to match("Found it on my alert")
      expect(response.body).to include(new_bike_path(stolen: true))
    end
  end

  describe "faq" do
    it "redirects other pages to index" do
      get "/stolen/faq"
      expect(response).to redirect_to stolen_index_url
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
