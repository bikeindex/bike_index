require "rails_helper"

RSpec.describe "Rack::Deflater", type: :request do
  it "returns gzip Content-Encoding when client accepts gzip" do
    get "/", headers: {"Accept-Encoding" => "gzip"}

    expect(response.status).to eq(200)
    expect(response.headers["Content-Encoding"]).to eq("gzip")
  end

  it "does not return gzip Content-Encoding when client does not accept gzip" do
    get "/"

    expect(response.status).to eq(200)
    expect(response.headers["Content-Encoding"]).to be_blank
  end
end
