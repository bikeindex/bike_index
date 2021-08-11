require "rails_helper"

RSpec.describe StolenController, type: :controller do
  describe "index" do
    it "renders with layout even if text" do
      get :index, format: :text
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "faq" do
    it "redirects other pages to index" do
      get :show, params: {id: "faq"}
      expect(response).to redirect_to stolen_index_url
    end
  end
end
