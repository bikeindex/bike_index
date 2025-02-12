require "rails_helper"

RSpec.describe CreateStolenGeojsonJob, type: :job do
  let(:instance) { described_class.new }
  # Have to do this here so that the scheduled worker test don't make requests
  before { allow_any_instance_of(Integrations::Cloudflare).to receive(:expire_cache) { true } }

  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "perform" do
    let!(:bike) { FactoryBot.create(:stolen_bike) }
    let!(:bike_no_lat) { FactoryBot.create(:stolen_bike) }
    it "creates geojson file" do
      # Test that bikes with no coordinates don't cause errors
      bike_no_lat.update_columns(latitude: nil, longitude: nil)
      instance.perform
      file = described_class.file
      expect(file.keys).to match_array(%w[path filename daily updated_at description])
      expect(file["filename"]).to eq "stolen.geojson"
      expect(file["daily"]).to be_truthy
      expect(file["updated_at"].to_i).to be_within(1).of Time.current.to_i
    end
  end
end
