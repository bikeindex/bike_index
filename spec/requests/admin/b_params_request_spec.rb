require "rails_helper"

base_url = "/admin/b_params"
RSpec.describe base_url, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:subject) { FactoryBot.create(:b_param) }

  describe "index" do
    it "responds with OK and renders the index template" do
      get base_url
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
      expect(response.body).to_not match(/bike errors/i)
    end

    context "with bike_errors" do
      before { subject.update(bike_errors: ["Frame material is not valid"]) }

      it "renders them" do
        get "#{base_url}/#{subject.to_param}"

        expect(response.code).to eq("200")
        expect(response.body).to match(/bike errors/i)
        expect(response.body).to match(/Frame material is not valid/)
      end
    end
  end
end
