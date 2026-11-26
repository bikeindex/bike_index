require "rails_helper"

RSpec.describe StolenController, type: :request do
  describe "index" do
    let!(:recovery_display) { FactoryBot.create(:recovery_display_with_photo, quote: "Found it on my alert", quote_by: "Sandy") }
    let!(:recovery_display_without_photo) { FactoryBot.create(:recovery_display, quote: "Still processing") }

    it "renders with layout even if text" do
      get "/stolen.txt"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq "text/html"
      expect(response.body).to match("Your bike is gone.")
      expect(response.body).to match("Found it on my alert")
      expect(response.body).to_not match("Still processing")
      expect(response.body).to include(new_register_path(status: "status_stolen"))
    end

    it "links to a registration that starts stolen, over an abandoned one" do
      get "/register/new"
      abandoned = BParam.last
      get "/stolen"
      get Nokogiri::HTML(response.body).at("a:contains('Register your stolen bike')")["href"]
      follow_redirect!
      expect(BParam.last.id).to_not eq abandoned.id
      expect(BParam.last.status).to eq "status_stolen"
    end
  end

  describe "reporting from the page" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    before { log_in(user) }

    it "re-renders the page when the report is missing its body" do
      expect {
        post "/feedbacks", params: {feedback: {feedback_type: "stolen_information", title: "Bike ChopShop report", body: ""}},
          headers: {"HTTP_REFERER" => "http://www.example.com/stolen"}
      }.to_not change(Feedback, :count)
      expect(response.status).to eq 200
      expect(response.body).to match("Your bike is gone.")
      expect(response.body).to match("Body can&#39;t be blank")
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
