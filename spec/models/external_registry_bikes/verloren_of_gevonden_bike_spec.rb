require "rails_helper"

module ExternalRegistryBikes
  RSpec.describe VerlorenOfGevondenBike, type: :model do
    describe "#build_from_api_response" do
      context "given a non-bike api response object" do
        it "returns nil" do
          bike = described_class.build_from_api_response(non_bike_json)
          expect(bike).to eq(nil)
        end
      end

      context "given a bike api response object" do
        subject(:bike) do
          described_class.build_from_api_response(bike_json)
        end

        it "returns a valid VerlorenOfGevondenBike instance" do
          expect(bike).to be_a(ExternalRegistryBike)
          expect(bike).to be_an_instance_of(VerlorenOfGevondenBike)
          expect(bike).to_not be_persisted
          expect(bike).to be_valid
        end

        it "correctly parses the bike search query url" do
          expect(bike.url).to match(%r{https://.+/overzicht\?search=.+})
        end

        it "parses the date stolen from the registration date in YY-mm-dd format" do
          expect(bike.date_stolen).to eq("2019-06-25")
        end

        it "parses the frame model" do
          expect(bike.frame_model).to eq("kinderfiets")
        end

        it "parses the brand / manufacturer name" do
          expect(bike.mnfg_name).to eq("Gazelle")
        end

        it "parses the frame colors" do
          expect(bike.frame_colors).to eq(["blauw"])
        end

        it "returns the location with country name if one is available" do
          expect(bike.location_found).to(eq <<~STR.chomp)
            Pieter Steynstraat, Rest van de stad Zwolle - NL
          STR
        end
      end
    end

    let(:non_bike_json) do
      JSON.parse(<<~JSON)
        {
          "ObjectId": "216594",
          "ObjectNumber": "G1708-2019000382",
          "ExternalNumber": "",
          "CityId": "3821",
          "City": "Steenwijk",
          "StorageLocationId": "1150509",
          "StorageLocation": "Gemeente Steenwijkerland",
          "CategoryId": "11",
          "Category": "portemonnee of portefeuille (met inhoud)",
          "SubCategoryId": "60",
          "SubCategory": "portemonnee",
          "ColorId": "7",
          "Color": "geel",
          "Description": "Kinderportemonee (geel) er zit een AH bonuskaart en in een foto uit 2017",
          "Brand": "",
          "RegistrationDate": "2019-06-26T14:01:00Z",
          "Deleted": "false",
          "ImageCount": "0",
          "CustomerId": "313",
          "OrganisationName": "Gemeente Steenwijkerland",
          "Country": "Nederland",
          "FormLink": "https://formulieren.verlorenofgevonden.nl/eigenaar?db=5116bfc8-6fd8-4d59-ae31-f336e7ac25eb&Number=G1708-2019000382"
        }
      JSON
    end

    let(:bike_json) do
      JSON.parse(<<~JSON)
        {
          "ObjectId": "269123",
          "ObjectNumber": "F0193f-193711472",
          "ExternalNumber": "193711472",
          "CityId": "4692",
          "City": "Zwolle",
          "StorageLocationId": "1150566",
          "StorageLocation": "AFAC Morsestraat 11",
          "CategoryId": "3",
          "Category": "fiets",
          "SubCategoryId": "27",
          "SubCategory": "kinderfiets",
          "ColorId": "2",
          "Color": "blauw",
          "Description": "kinderfiets Gazelle ( blauw ) met framenummer 'GZ1008382'. \\r\\nLocatie gevonden: Pieter Steynstraat, Rest van de stad Zwolle. \\r\\nDirecte verwijdering fiets op 25-6-2019 en overgebracht naar depot AFAC Morsestraat 11 op 25-6-2019, opslag t/m 21-8-2019.",
          "Brand": "Gazelle",
          "RegistrationDate": "2019-06-26T09:48:00Z",
          "Deleted": "false",
          "ImageCount": "1",
          "CustomerId": "249",
          "OrganisationName": "Gemeente Zwolle",
          "Country": "Nederland",
          "FormLink": "&Number=F0193f-193711472"
        }
      JSON
    end
  end
end
