require "rails_helper"

RSpec.describe Search::BikebookController, type: :request do
  describe "index" do
    it "answers with no content, as its log line is the search's record" do
      get "/search/bikebook", params: {q: "gt3", count: "2"}
      expect(response.status).to eq 204
      expect(response.body).to be_empty
    end
  end
end
