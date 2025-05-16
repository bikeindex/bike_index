require "rails_helper"

RSpec.describe "IpAddressParser" do
  let(:request) { double("request", env:) }

  describe ".forwarded_address" do
    let(:env) do
      {
        "HTTP_CF_CONNECTING_IP" => "192.168.1.1",
        "HTTP_X_FORWARDED_FOR" => "10.0.0.1,10.0.0.2",
        "REMOTE_ADDR" => "172.16.0.1",
        "ip" => "127.0.0.1"
      }
    end

    it "returns the HTTP_CF_CONNECTING_IP value" do
      expect(IpAddressParser.forwarded_address(request)).to eq("192.168.1.1")
    end

    context "when HTTP_CF_CONNECTING_IP is not present but HTTP_X_FORWARDED_FOR is" do
      let(:env) do
        {
          "HTTP_X_FORWARDED_FOR" => "10.0.0.1,10.0.0.2",
          "REMOTE_ADDR" => "172.16.0.1",
          "ip" => "127.0.0.1"
        }
      end

      it "returns the last IP from HTTP_X_FORWARDED_FOR" do
        expect(IpAddressParser.forwarded_address(request)).to eq("10.0.0.2")
      end
    end

    context "when HTTP_X_FORWARDED_FOR is not present but REMOTE_ADDR is" do
      let(:env) { {"REMOTE_ADDR" => "172.16.0.1", "ip" => "127.0.0.1"} }

      it "returns the REMOTE_ADDR value" do
        expect(IpAddressParser.forwarded_address(request)).to eq("172.16.0.1")
      end
    end

    context "when only ip is present" do
      let(:env) { {"ip" => "127.0.0.1"} }

      it "returns the ip value" do
        expect(IpAddressParser.forwarded_address(request)).to eq("127.0.0.1")
      end
    end

    context "when no IP address sources are present" do
      let(:env) { {} }
      it "returns nil" do
        expect(IpAddressParser.forwarded_address(request)).to be_nil
      end
    end
  end

  describe ".location_hash" do
    let(:env) do
      {
        "HTTP_CF_IPCITY" => "San Francisco",
        "HTTP_CF_IPLATITUDE" => "37.7749",
        "HTTP_CF_IPLONGITUDE" => "-122.4194",
        "HTTP_CF_IPCOUNTRY" => "US",
        "HTTP_CF_POSTAL_CODE" => "94107",
        "HTTP_CF_REGION" => "California"
      }
    end
    let(:target_hash) do
      {
        city: "San Francisco",
        latitude: 37.7749,
        longitude: -122.4194,
        formatted_address: nil,
        country_id: Country.united_states_id,
        neighborhood: nil,
        street: nil,
        postal_code: "94107",
        region_string: "California"
      }
    end

    it "returns a complete location hash" do
      expect(IpAddressParser.location_hash(request)).to eq(target_hash)
    end

    context "no location headers present" do
      let(:env) { {"REMOTE_ADDR" => "172.16.0.1", "ip" => "127.0.0.1"} }
      let(:target_hash) do
        {
          city: nil,
          latitude: nil,
          longitude: nil,
          formatted_address: nil,
          country_id: nil,
          neighborhood: nil,
          street: nil,
          postal_code: nil,
          region_string: nil
        }
      end
      it "returns empty location hash" do
        expect(IpAddressParser.location_hash(request)).to eq(target_hash)
      end
    end
  end
end
