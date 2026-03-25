require "rails_helper"

RSpec.describe IpSpoofAttackFilter, type: :request do
  context "when IP headers are spoofed" do
    let(:spoofed_headers) do
      {
        "HTTP_CLIENT_IP" => "251.252.74.114",
        "HTTP_X_FORWARDED_FOR" => "211.112.215.202,109.123.246.221, 172.71.131.189"
      }
    end

    it "returns 403" do
      get "/", headers: spoofed_headers

      expect(response.status).to eq(403)
      expect(response.body).to eq("Forbidden")
    end

    context "with HTTP_FORWARDED header" do
      let(:spoofed_headers) do
        super().merge("HTTP_FORWARDED" => "for=211.112.215.202, for=109.123.246.221, for=172.71.131.189")
      end

      it "returns 403" do
        get "/", headers: spoofed_headers

        expect(response.status).to eq(403)
        expect(response.body).to eq("Forbidden")
      end
    end
  end
end
