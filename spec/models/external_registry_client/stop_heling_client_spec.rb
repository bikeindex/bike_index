require "rails_helper"

RSpec.describe ExternalRegistryClient::StopHelingClient, type: :model do
  before do
    null_cache = ActiveSupport::Cache.lookup_store(:null_store)
    allow(Rails).to receive(:cache).and_return(null_cache)
    FactoryBot.create(:stop_heling_credentials)
  end

  after do
    allow(Rails).to receive(:cache).and_call_original
  end

  describe "#search" do
    context "given no matching results" do
      it "returns an empty array" do
        client = build_client
        results = client.search("nothing")
        expect(results).to be_empty
      end
    end

    context "given matching results but no bikes" do
      it "returns an empty array" do
        client = build_client(results: [non_bike_result])
        results = client.search("28484")
        expect(results).to be_empty
      end
    end

    context "given matching results but no bikes" do
      it "returns an array of ExternalRegistryBikes" do
        client = build_client(results: [bike_result])
        results = client.search("28484")
        expect(results).to_not be_empty
        expect(results).to all(be_an_instance_of(ExternalRegistryBike::StopHelingBike))
      end
    end
  end

  let(:bike_result) do
    {
      "Korpscode" => "PL2100",
      "Registratienummer" => "2016108799",
      "Kleur" => "ONBEKEND",
      "Merk" => "GAZELLE",
      "Merktype" => "ORANGE PLUS ORA",
      "Categorie" => "DK42",
      "Object" => "FIETS",
      "Kenteken_regnr" => "GZ8638225",
      "Motor_serienr" => "",
      "Chassis_graveer" => "999052802401171",
      "Uniek_nummer" => "",
      "Datuminvoer" => "2016-05-16T00:00:00",
      "Datumwijziging" => "2016-05-16T00:00:00",
      "Insertdate" => "2016-12-01T12:03:00",
      "Bron" => "KOH",
      "BronNaam" => "POLITIE BRABANT-NOORD",
      "BronUniekID" => "458171",
      "MatchType" => "PARTIAL HIT",
    }
  end

  let(:non_bike_result) do
    {
      "Korpscode" => "PL1200",
      "Registratienummer" => "2010034555",
      "Kleur" => "BEIGE",
      "Merk" => "PEUGEOT",
      "Merktype" => "406 2.0 16V AU",
      "Categorie" => "DK42",
      "Object" => "PERSONENAUTO",
      "Kenteken_regnr" => "RNZD44",
      "Motor_serienr" => "",
      "Chassis_graveer" => "VF38BRFVP80328484",
      "Uniek_nummer" => nil,
      "Datuminvoer" => "2010-04-02T00:00:00",
      "Datumwijziging" => "2010-04-02T00:46:00",
      "Insertdate" => "2010-10-06T10:06:00",
      "Bron" => "KOH",
      "BronNaam" => "POLITIE KENNEMERLAND",
      "BronUniekID" => "83760",
      "MatchType" => "PARTIAL HIT",
    }
  end

  def build_client(endpoint: "GetSearchItems", results: [])
    client = described_class.new

    unless ENV["LIVE_EXTERNAL_API_SPECS"] == "true"
      allow(client.conn).to(receive(:get)
        .with(endpoint)
        .and_return(double(:response, body: results)))
    end

    client
  end
end
