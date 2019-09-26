require "rails_helper"

module ExternalRegistries
  RSpec.describe VerlorenOfGevondenResult, type: :model do
    describe "#bike?" do
      it "returns true given a bike entry" do
        result = described_class.new(bike_json)
        expect(result).to be_bike
      end

      it "returns false given a non-bike entry" do
        result = described_class.new(non_bike_json)
        expect(result).to_not be_bike
      end
    end

    describe "#url" do
      it "returns a valid search query url" do
        result = described_class.new(bike_json)
        expect(result.url).to match(%r{https://.+/overzicht\?search=.+})

        result = described_class.new(non_bike_json)
        expect(result.url).to match(%r{https://.+/overzicht\?search=.+})
      end
    end

    describe "#date_found" do
      it "returns the date, in YY-mm-dd format" do
        result = described_class.new(non_bike_json)
        expect(result.date_found.to_date.to_s).to eq("2019-06-26")

        result = described_class.new(bike_json)
        expect(result.date_found.to_date.to_s).to eq("2019-06-25")
      end
    end

    describe "#location_found" do
      context "if a location found is available" do
        it "returns the location" do
          result = described_class.new(bike_json)
          expect(result.location_found).to eq("Pieter Steynstraat, Rest van de stad Zwolle")
        end
      end

      context "if no location found is but storage location (string) is available" do
        it "returns the storage location" do
          result = described_class.new(non_bike_json)
          expect(result.location_found).to eq("Gemeente Steenwijkerland")
        end
      end

      context "if no location found is but storage location (object) is available" do
        it "returns the storage location name and city" do
          result = described_class.new(non_bike_json)
          allow(result)
            .to(receive(:storage_location)
              .and_return("Name" => "Gemeente", "City" => "Steenwijkerland"))
          expect(result.location_found).to eq("Gemeente Steenwijkerland")
        end
      end
    end

    describe "#subcategory" do
      it "returns the frame type" do
        result = described_class.new(bike_json)
        expect(result.subcategory).to eq("kinderfiets")

        result = described_class.new(non_bike_json)
        expect(result.subcategory).to eq("portemonnee")
      end
    end

    describe "#brand" do
      it "returns the frame type" do
        result = described_class.new(bike_json)
        expect(result.brand).to eq("Gazelle")

        result = described_class.new(non_bike_json)
        expect(result.brand).to eq("Unknown Brand")
      end
    end

    describe "#color" do
      it "returns the frame type" do
        result = described_class.new(bike_json)
        expect(result.color).to eq("blauw")

        result = described_class.new(non_bike_json)
        expect(result.color).to eq("geel")
      end
    end

    describe "#to_external_registry_bike" do
      it "returns an ExternalRegistryBike" do
        result =
          described_class
            .new(bike_json)
            .to_external_registry_bike
        expect(result).to be_an_instance_of(ExternalRegistryBike)
      end
    end

    let(:non_bike_json) do
      JSON.parse(<<~JSON.gsub(/\s/, " "))
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
      JSON.parse(<<~JSON.gsub(/\s/, " "))
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
          "Description": "kinderfiets Gazelle ( blauw ) met framenummer 'GZ1008382'.\r\nLocatie gevonden: Pieter Steynstraat, Rest van de stad Zwolle.\r\nDirecte verwijdering fiets op 25-6-2019 en overgebracht naar depot AFAC Morsestraat 11 op 25-6-2019, opslag t/m 21-8-2019.",
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
