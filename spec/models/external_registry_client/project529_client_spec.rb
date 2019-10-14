require "rails_helper"

RSpec.describe ExternalRegistryClient::Project529Client, type: :model do
  before do
    null_cache = ActiveSupport::Cache.lookup_store(:null_store)
    allow(Rails).to receive(:cache).and_return(null_cache)
  end

  after do
    allow(Rails).to receive(:cache).and_call_original
  end

  describe "#bikes" do
    context "given no results" do
      it "returns an empty collection" do
        VCR.use_cassette("external_registry/project529_bikes_with_no_results") do
          FactoryBot.create(:project529_credentials)
          results = described_class.new.bikes(updated_at: Time.parse("2001-01-01"))
          expect(results).to be_an(ActiveRecord::Relation)
          expect(results).to be_empty
        end
      end
    end

    context "given found results" do
      it "returns a collection of Project529Bike objects" do
        VCR.use_cassette("external_registry/project529_bikes_with_results") do
          FactoryBot.create(:project529_credentials)
          results = described_class.new.bikes(updated_at: Time.parse("2019-10-08"))
          expect(results).to be_an(ActiveRecord::Relation)
          expect(results).to all(be_an_instance_of(ExternalRegistryBike::Project529Bike))
          expect(results).to_not be_empty
        end
      end
    end
  end
end
