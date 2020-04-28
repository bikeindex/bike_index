require "rails_helper"

RSpec.describe ExternalRegistryClient::VerlorenOfGevondenClient, type: :model do
  RUN_EXTERNAL_VERLOREN_TESTS = ENV["VERLOREN_OF_GEVONDEN_BASE_URL"] != "test"

  before do
    null_cache = ActiveSupport::Cache.lookup_store(:null_store)
    allow(Rails).to receive(:cache).and_return(null_cache)
  end

  after do
    allow(Rails).to receive(:cache).and_call_original
  end

  describe "#search" do
    context "given a valid query" do
      it "returns search results", if: RUN_EXTERNAL_VERLOREN_TESTS do
        VCR.use_cassette("external_registry/verlorenofgevonden_2722_with_results") do
          results = described_class.new.search(2722)

          expect(results).to be_present
          expect(results).to be_an(Array)
          expect(results).to all(be_an_instance_of(ExternalRegistryBike::VerlorenOfGevondenBike))
          expect(results.none?(&:persisted?)).to eq(true)
          expect(results.map(&:description)).to all(match(/fiets/))
          expect(results.first.external_id).to match(/F\d+\w*-.+/)
          expect(results.first.serial_number).to be_present
          fail
        end
      end
    end

    context "given no results" do
      it "returns an empty collection", if: RUN_EXTERNAL_VERLOREN_TESTS do
        VCR.use_cassette("external_registry/verlorenofgevonden_13949483_no_results") do
          results = described_class.new.search(13949483)
          expect(results).to be_an(Array)
          expect(results).to be_empty
          fail
        end
      end
    end

    context "given an invalid query" do
      it "returns an empty collection", if: RUN_EXTERNAL_VERLOREN_TESTS do
        results = described_class.new.search("")
        expect(results).to be_an(Array)
        expect(results).to be_empty
        fail
      end
    end
  end
end
