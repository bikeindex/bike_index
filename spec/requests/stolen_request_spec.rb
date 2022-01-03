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
end
