require "rails_helper"

RSpec.describe Admin::BParamsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:subject) { BParam.create(creator_id: user.id) }

  describe "index" do
    it "responds with OK and renders the index template" do
      get "/admin/b_params"
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
      get "#{base_url}?query=something"
      expect(response).to render_template :index
    end
  end

  describe "show" do
    it "responds with OK and renders the show template" do
      get "/admin/b_params/#{subject.to_param}"

      expect(response.code).to eq("200")
      expect(response).to render_template(:show)
    end
  end
end
