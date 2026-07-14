require "rails_helper"

RSpec.describe "API Base", type: :request do
  describe "malformed multipart body" do
    # A client sending Content-Type: multipart/form-data with an empty body makes
    # Rack raise Rack::Multipart::EmptyContentError when grape_logging reads params.
    # It should be treated as a client error (400), not a 500 that pages us.
    it "responds 400 instead of 500" do
      post "/api/v2/manufacturers",
        headers: {"CONTENT_TYPE" => "multipart/form-data; boundary=----WebKitFormBoundary"},
        env: {"rack.input" => StringIO.new(""), "CONTENT_LENGTH" => nil}

      expect(response.response_code).to eq(400)
    end
  end
end
