require "rails_helper"

base_url = "/admin/b_params"
RSpec.describe base_url, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:subject) { FactoryBot.create(:b_param) }

  describe "index" do
    it "responds with OK and renders the index template" do
      get base_url.to_s
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
      get "#{base_url}?query=something"
      expect(response).to render_template :index
    end
  end

  describe "show" do
    it "responds with OK and renders the show template" do
      get "#{base_url}/#{subject.to_param}"

      expect(response.code).to eq("200")
      expect(response).to render_template(:show)
    end
  end
end
