require "rails_helper"

RSpec.describe ErrorsController, type: :request do
  describe "bad_request" do
    it "renders" do
      get "/400"
      expect(response.status).to eq(400)
      expect(response).to render_template(:bad_request)
    end
  end

  describe "unauthorized" do
    it "renders" do
      get "/401", params: {format: :json}
      expect(response.status).to eq(401)
      expect(response).to render_template(:unauthorized)
    end
  end

  describe "not_found" do
    it "renders" do
      get "/404"
      expect(response.status).to eq(404)
      expect(response).to render_template(:not_found)
    end
  end

  describe "unprocessable_entity" do
    it "renders" do
      get "/422", params: {format: :json}
      expect(response.status).to eq(422)
      expect(response).to render_template(:unprocessable_entity)
    end
  end

  context "rendered for an exception, as in production" do
    include_context :request_spec_production_exceptions

    it "renders the error page for malformed params" do
      # Unrouted, so the request fails before reading them - only the error page does
      post "/", params: "{not json", headers: {"CONTENT_TYPE" => "application/json"}
      expect(response.status).to eq 404
      expect(response).to render_template(:not_found)

      post "/", params: "garbage", headers: {"CONTENT_TYPE" => "multipart/form-data; boundary=xyz"}
      expect(response.status).to eq 404
      expect(response).to render_template(:not_found)

      get "/not-a-route?a=%E0%A4%A"
      expect(response.status).to eq 404
      expect(response).to render_template(:not_found)

      get "/?a=%E0%A4%A"
      expect(response.status).to eq 400
      expect(response).to render_template(:bad_request)

      post "/session/identify", params: "{not json", headers: {"CONTENT_TYPE" => "application/json"}
      expect(response.status).to eq 400
      expect(response).to render_template(:bad_request)
    end

    it "keeps parseable params" do
      get "/not-a-route?locale=nl"
      expect(response.status).to eq 404
      expect(response.body).to include('<html lang="nl">')
    end
  end

  # Since this renders a 500, it doesn't test right.
  # describe 'server_error' do
  #   it 'renders' do
  #     get :server_error, params: {format: :json}
  #     expect(response.status).to eq(500)
  #     expect(response).to render_template(:server_error)
  #   end
  # end
end
