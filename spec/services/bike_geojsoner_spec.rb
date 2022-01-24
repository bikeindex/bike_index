require "rails_helper"

RSpec.describe BikeGeojsoner do
  describe "geojson_feature" do
    let(:bike) { FactoryBot.build(:bike, :in_amsterdam) }
    it "returns nil" do
      expect(bike.to_coordinates).to eq([52.37403, 4.88969])
      expect(described_class.feature(bike)).to be_blank
    end
    context "stolen" do
      let(:date_stolen) { Time.current - 6.hours }
      let(:bike) { FactoryBot.create(:bike, :with_stolen_record, date_stolen: date_stolen) }
      let(:target) do
        {
          type: "Feature",
          properties: {
            :bike_id => bike.id,
            :kind => "theft",
            :occurred_at => date_stolen.to_i,
            :title => bike.title_string,
            "marker-size" => "small",
            "marker-color" => "#BD1622"
          },
          geometry: {
            type: "Point",
            coordinates: [-74.01, 40.71]
          }
        }
      end
      it "returns target" do
        expect(bike.reload.to_coordinates).to eq([40.7143528, -74.0059731])
        expect(bike.current_stolen_record.date_stolen).to be_within(1).of date_stolen
        expect_hashes_to_match(described_class.feature(bike), target)
      end
    end
  end
end
