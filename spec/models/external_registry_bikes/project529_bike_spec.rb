require "rails_helper"

module ExternalRegistryBikes
  RSpec.describe Project529Bike, type: :model do
    before do
      FactoryBot.create(:country, name: "Canada", iso: "CA")
      FactoryBot.create(:country, name: "United States", iso: "US")
    end

    describe ".build_from_api_response" do
      it "returns a valid ExternalRegistryBike object" do
        bike = described_class.build_from_api_response(bike_json)

        expect(bike).to an_instance_of(described_class)
        expect(bike).to_not be_persisted
        expect(bike.valid?).to eq(true), bike.errors.full_messages.to_sentence
      end

      it "sources attribute values correctly" do
        bike = described_class.build_from_api_response(bike_json)

        expect(bike.type).to eq(described_class.to_s)
        expect(bike.external_id).to eq(bike_json["id"].to_s)
        expect(bike.serial_number).to eq(bike_json["serial_number"].to_s)
        expect(bike.status).to eq(bike_json["status"])
        expect(bike.description).to eq("We The People Arcade")
        expect(bike.mnfg_name).to eq("We The People")
        expect(bike.frame_colors).to eq(["Red", "Gold"])
        expect(bike.frame_model).to eq("Arcade")
        expect(bike.date_stolen).to eq(bike_json.dig("active_incident", "last_seen"))
        expect(bike.location_found).to eq(bike_json.dig("active_incident", "location_address"))
        expect(bike.url).to match("https://project529.com/.+")
        expect(bike.image_url).to match("https://529garage-production.s3.amazonaws.com/photos/attachments")
        expect(bike.thumb_url).to match("https://529garage-production.s3.amazonaws.com/photos/attachments")
      end
    end

    let(:bike_json) do
      JSON.parse(<<~JSON)
        {
          "id": 539617,
          "serial_number": "HMQIL848992",
          "manufacturer_string": "We The People",
          "model_string": "Arcade",
          "build_string": null,
          "primary_color": "Red",
          "secondary_color": "Gold",
          "model_year": null,
          "size": null,
          "bike_type": null,
          "shield": "",
          "ext_number": null,
          "description": null,
          "status": "Stolen",
          "show_on_hotsheet": true,
          "updated_at": "2019-10-07T02:29:04.880Z",
          "created_at": "2019-08-23T01:18:05.191Z",
          "active_incident": {
            "id": 23307,
            "bolo_message": "Greenhorn sticker on front post, DGK white letter sticker on lef bottom post",
            "case_number": "",
            "created_at": "2019-10-07T02:29:01.250Z",
            "last_seen": "2019-06-11T00:50:00.000Z",
            "lat": "50.264911",
            "lng": "-119.273843",
            "location_address": "1630 23 St, London, BC Y8T 9O9, Canada",
            "location_description": "",
            "recovered_at": null,
            "recovered_how": null,
            "reward": "$100",
            "bolo_photos": [
              {
                "id": 585812,
                "mobile_uuid": null,
                "photo_type": "Unique Feature",
                "photo_type_id": 8,
                "description": null,
                "show_on_bolo": true,
                "private": false,
                "original_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/812/large/P529_20190822_181729_393_original.jpg?1566523100",
                "medium_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/812/medium/P529_20190822_181729_393_original.jpg?1566523100",
                "square_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/812/square/P529_20190822_181729_393_original.jpg?1566523100",
                "thumb_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/812/thumb/P529_20190822_181729_393_original.jpg?1566523100",
                "lat": null,
                "lon": null,
                "created_at": "2019-08-23T01:18:32.029Z",
                "updated_at": "2019-08-23T01:18:32.029Z"
              },
              {
                "id": 585814,
                "mobile_uuid": null,
                "photo_type": "Bike Side",
                "photo_type_id": 3,
                "description": null,
                "show_on_bolo": true,
                "private": false,
                "original_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/814/large/P529_20190822_181747_070_original.jpg?1566523144",
                "medium_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/814/medium/P529_20190822_181747_070_original.jpg?1566523144",
                "square_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/814/square/P529_20190822_181747_070_original.jpg?1566523144",
                "thumb_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/585/814/thumb/P529_20190822_181747_070_original.jpg?1566523144",
                "lat": null,
                "lon": null,
                "created_at": "2019-08-23T01:19:17.459Z",
                "updated_at": "2019-08-23T01:19:17.459Z"
              },
              {
                "id": 591083,
                "mobile_uuid": null,
                "photo_type": "Serial Number",
                "photo_type_id": 5,
                "description": null,
                "show_on_bolo": true,
                "private": false,
                "original_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/591/083/large/P529_20190822_181606_579_original.jpg?1566926411",
                "medium_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/591/083/medium/P529_20190822_181606_579_original.jpg?1566926411",
                "square_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/591/083/square/P529_20190822_181606_579_original.jpg?1566926411",
                "thumb_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/591/083/thumb/P529_20190822_181606_579_original.jpg?1566926411",
                "lat": null,
                "lon": null,
                "created_at": "2019-08-27T17:20:16.598Z",
                "updated_at": "2019-08-27T17:20:16.598Z"
              }
            ],
            "bolo_hero": null,
            "status": 2,
            "url": "https://project529.com/frame-shifter-gear-ring",
            "email": null,
            "phone": "928774922",
            "name": "John Doe",
            "updated_at": "2019-10-07T02:35:10.947Z"
          }
        }
      JSON
    end
  end
end
