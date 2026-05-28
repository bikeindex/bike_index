require "rails_helper"

RSpec.describe ScheduledSearchForExternalRegistryBikesJob, type: :job do
  before { ExternalRegistryBike.delete_all }

  describe "skip_scheduling?" do
    let(:instance) { described_class.new }

    it "is false when VERLOREN_OF_GEVONDEN_BASE_URL is set" do
      # .env sets VERLOREN_OF_GEVONDEN_BASE_URL=test for the test env
      expect(ENV["VERLOREN_OF_GEVONDEN_BASE_URL"]).to be_present
      expect(instance.skip_scheduling?).to be_falsey
    end

    context "when VERLOREN_OF_GEVONDEN_BASE_URL is blank" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("VERLOREN_OF_GEVONDEN_BASE_URL").and_return(nil)
      end

      it "is true" do
        expect(instance.skip_scheduling?).to be_truthy
      end
    end
  end

  describe "#perform" do
    context "given no bikes currently stolen in the Netherlands" do
      it "does not enqueue any work" do
        FactoryBot.create(:stolen_bike_in_nyc)
        expect(SearchForExternalRegistryBikesJob.jobs.length).to eq(0)
        described_class.new.perform
        expect(SearchForExternalRegistryBikesJob.jobs.length).to eq(0)
      end
    end

    context "given bikes currently stolen in the Netherlands" do
      it "enqueues a search for each unique normalized serial number" do
        FactoryBot.create(:stolen_bike_in_nyc)
        FactoryBot.create_list(:stolen_bike_in_amsterdam, 2)
        expect(SearchForExternalRegistryBikesJob.jobs.length).to eq(0)
        described_class.new.perform
        expect(SearchForExternalRegistryBikesJob.jobs.length).to eq(2)
      end
    end
  end
end
