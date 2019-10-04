require "rails_helper"

RSpec.describe EnqueueSearchesForExternalRegistryBikesWorker, type: :job do
  before { ExternalRegistryBike.delete_all }

  describe "#perform" do
    context "given no bikes currently stolen in the Netherlands" do
      it "does not enqueue any work" do
        FactoryBot.create(:stolen_bike_in_nyc)
        expect(SearchForExternalRegistryBikesWorker.jobs.length).to eq(0)
        described_class.new.perform
        expect(SearchForExternalRegistryBikesWorker.jobs.length).to eq(0)
      end
    end

    context "given bikes currently stolen in the Netherlands" do
      it "enqueues a search for each unique normalized serial number" do
        FactoryBot.create(:stolen_bike_in_nyc)
        FactoryBot.create_list(:stolen_bike_in_amsterdam, 2)
        expect(SearchForExternalRegistryBikesWorker.jobs.length).to eq(0)
        described_class.new.perform
        expect(SearchForExternalRegistryBikesWorker.jobs.length).to eq(2)
      end
    end
  end
end
