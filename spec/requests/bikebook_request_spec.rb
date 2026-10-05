require "rails_helper"

RSpec.describe BikebookController, type: :request do
  describe "show" do
    it "renders the search and a spinner, and the shell the browser fills in from the catalog" do
      get "/bikebook"

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      bikebook = page.find("[data-controller='bikebook--page']")
      expect(bikebook["data-bikebook--page-manifest-url-value"]).to eq BikebookController::MANIFEST_URL
      expect(bikebook).to have_css("[inert] #vehicle_models")
        .and have_css("[role='status'] svg.tw\\:animate-spin")

      shell = Capybara.string(Nokogiri::HTML5(response.body).at_css("template[data-bikebook--page-target='shell']").inner_html)
      expect(shell).to have_field("vehicle_models", placeholder: "Search by manufacturer or model…")
        .and have_css("#manufacturer-hw-listbox", visible: :all)
        .and have_css("#vehicle-viewers", visible: :all)
    end
  end

  describe "vehicle" do
    it "redirects to the page with that vehicle picked" do
      get "/bikebook/m/segway/2025/gt3_pro"
      expect(response).to redirect_to("/bikebook?vehicle_models=m/segway/2025/gt3_pro")
    end

    context "without its m/, and with vehicles already picked" do
      it "picks it ahead of them, keeping the query" do
        get "/bikebook/segway/2025/gt3_pro", params: {vehicle_models: "m/aventon/2022/level_2,m/segway/2025/gt3_pro", filters: "1"}
        expect(response).to redirect_to("/bikebook?filters=1&vehicle_models=m/segway/2025/gt3_pro,m/aventon/2022/level_2")
      end
    end
  end
end
