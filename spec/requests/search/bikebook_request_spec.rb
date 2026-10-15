require "rails_helper"

RSpec.describe Search::BikebookController, type: :request do
  describe "index" do
    it "answers with no content, as its log line is the search's record" do
      get "/search/bikebook", params: {q: "gt3", count: "2"}
      expect(response.status).to eq 204
    end
  end

  describe "rack_attack" do
    include_context :rack_attack

    # Bikebook makes no request per page, so its searches' logs don't spend the per-page budget
    it "throttles at the API limit, not the lower per-page limit" do
      throttled = rack_attack_throttled_response(limit: Rack::Attack::API_MAX_REQUESTS) do
        get "/search/bikebook", params: {q: "gt3"}
        response
      end
      expect(throttled).to have_http_status(:too_many_requests)
    end
  end
end
