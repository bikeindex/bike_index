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
        expect(bike.status).to eq(bike_json["status"].downcase)
        expect(bike.frame_model).to eq(bike_json["model_string"])
        expect(bike.date_stolen).to eq(bike_json.dig("active_incident", "last_seen"))
        expect(bike.location_found).to eq(bike_json.dig("active_incident", "location_address"))
        expect(bike.mnfg_name).to eq(bike_json["manufacturer_string"])
        expect(bike.description).to eq("2015 SE Racing 700C Lager")
        expect(bike.frame_colors).to eq(["Red", "Gold"])
        expect(bike.url).to match("https://project529.com/.+")
        expect(bike.image_url).to match("https://529garage-production.s3.amazonaws.com/photos/attachments")
        expect(bike.thumb_url).to match("https://529garage-production.s3.amazonaws.com/photos/attachments")
      end
    end

    let(:bike_json) do
      JSON.parse(<<~JSON)
        {
            "id": 263367,
            "url": "https://project529.com/fender-wrench-pannier-bell",
            "additional_equipment": null,
            "bike_type": null,
            "build_string": null,
            "number_of_gears": null,
            "wheel_size": null,
            "insured": null,
            "manufacturer_id": 358,
            "manufacturer_string": "SE Racing",
            "model_string": "700C Lager",
            "model_year": 2015,
            "primary_color": "Red",
            "secondary_color": "Gold",
            "serial_number": "8282928474",
            "shield": null,
            "size": null,
            "slug": "fender-wrench-pannier-bell",
            "status": "Stolen",
            "value": 0,
            "created_at": "2017-04-09T02:12:19.509Z",
            "updated_at": "2019-10-02T03:25:47.080Z",
            "bike_photos": [
                {
                    "id": 155529,
                    "photo_type": "Side",
                    "description": "",
                    "original_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/529/large/image.jpg?1491729146",
                    "medium_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/529/medium/image.jpg?1491729146",
                    "square_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/529/square/image.jpg?1491729146",
                    "thumb_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/529/thumb/image.jpg?1491729146",
                    "lat": null,
                    "lon": null,
                    "created_at": "2017-04-09T09:12:28.431Z",
                    "updated_at": "2017-04-09T09:12:28.431Z"
                },
                {
                    "id": 155532,
                    "photo_type": "What to look for",
                    "description": "",
                    "original_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/532/large/image.jpg?1491729159",
                    "medium_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/532/medium/image.jpg?1491729159",
                    "square_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/532/square/image.jpg?1491729159",
                    "thumb_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/532/thumb/image.jpg?1491729159",
                    "lat": null,
                    "lon": null,
                    "created_at": "2017-04-09T09:12:40.898Z",
                    "updated_at": "2017-04-09T09:12:40.898Z"
                },
                {
                    "id": 155530,
                    "photo_type": "Serial Number",
                    "description": "",
                    "original_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/530/large/image.jpg?1491729150",
                    "medium_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/530/medium/image.jpg?1491729150",
                    "square_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/530/square/image.jpg?1491729150",
                    "thumb_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/530/thumb/image.jpg?1491729150",
                    "lat": null,
                    "lon": null,
                    "created_at": "2017-04-09T09:12:31.807Z",
                    "updated_at": "2017-04-09T09:12:31.807Z"
                },
                {
                    "id": 155531,
                    "photo_type": "Shield",
                    "description": "",
                    "original_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/531/large/image.jpg?1491729154",
                    "medium_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/531/medium/image.jpg?1491729154",
                    "square_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/531/square/image.jpg?1491729154",
                    "thumb_url": "https://529garage-production.s3.amazonaws.com/photos/attachments/000/155/531/thumb/image.jpg?1491729154",
                    "lat": null,
                    "lon": null,
                    "created_at": "2017-04-09T09:12:36.618Z",
                    "updated_at": "2017-04-09T09:12:36.618Z"
                }
            ],
            "active_incident": {
                "id": 23122,
                "bolo_message": "has a sport seat and white drop bars, and clip in pedals\\n",
                "case_number": null,
                "last_seen": "2019-09-20T03:20:00.000Z",
                "lat": "0.0",
                "lng": "0.0",
                "law_enforcement_agency_string": null,
                "location_address": "Cambridge, MA 02138, USA",
                "location_description": "stolen out of garage\\n1212 patterson\\nwhite bar tape",
                "lock_defeated": null,
                "lock_type": null,
                "notes": null,
                "reward": "$50",
                "was_locked": null,
                "updated_at": "2019-10-02T03:25:46.964Z",
                "created_at": "2019-10-02T03:25:46.782Z"
            }
        }
      JSON
    end
  end
end
