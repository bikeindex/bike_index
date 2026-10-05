require "rails_helper"

RSpec.describe BikebookController, type: :request do
  describe "show" do
    let!(:standard_wheel_size) { FactoryBot.create(:wheel_size, iso_bsd: 622, priority: :standard) }
    let!(:rare_wheel_size) { FactoryBot.create(:wheel_size, iso_bsd: 203, priority: :rare) }

    it "renders the shell the browser fills in from the catalog, with the standard wheel sizes" do
      get "/bikebook"

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      bikebook = page.find("[data-controller='bikebook']")
      expect(bikebook["data-bikebook-manifest-url-value"]).to eq BikebookController::MANIFEST_URL
      expect(JSON.parse(bikebook["data-bikebook-standard-wheel-sizes-value"])).to eq [622]
      expect(bikebook).to have_text("Loading the catalog…")

      shell = Capybara.string(Nokogiri::HTML5(response.body).at_css("template[data-bikebook-target='shell']").inner_html)
      expect(shell).to have_field("vehicle_models", placeholder: "Search by manufacturer or model…")
        .and have_css("#manufacturer-hw-listbox", visible: :all)
        .and have_css("#vehicle-viewers", visible: :all)
    end
  end
end
