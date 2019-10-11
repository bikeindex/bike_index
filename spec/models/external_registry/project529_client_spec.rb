require "rails_helper"

module ExternalRegistry
  RSpec.describe Project529Client, type: :model do
    before do
      null_cache = ActiveSupport::Cache.lookup_store(:null_store)
      allow(Rails).to receive(:cache).and_return(null_cache)
    end

    after do
      allow(Rails).to receive(:cache).and_call_original
    end

    let(:client) do
      described_class.new.tap do |client|
        allow(client).to receive(:access_token).and_return("test")
      end
    end

    describe "#bikes" do
      context "given an authentication failure" do
        it "raises Project529ClientInvalidCredentialsError" do
          VCR.use_cassette("external_registry/project529_authentication_redirect") do
            expect { client.bikes }.to raise_error(Project529ClientInvalidCredentialsError)
          end
        end
      end

      context "given no results" do
        it "returns an empty collection" do
          VCR.use_cassette("external_registry/project529_bikes_with_no_results") do
            results = client.bikes(updated_at: Time.parse("2001-01-01"))
            expect(results).to be_an(ActiveRecord::Relation)
            expect(results).to be_empty
          end
        end
      end

      context "given found results" do
        it "returns a collection of Project529Bike objects" do
          VCR.use_cassette("external_registry/project529_bikes_with_results") do
            results = client.bikes(updated_at: Time.parse("2019-10-08"))
            expect(results).to be_an(ActiveRecord::Relation)
            expect(results).to all(be_an_instance_of(ExternalRegistryBikes::Project529Bike))
            expect(results).to_not be_empty
          end
        end
      end
    end
  end
end
