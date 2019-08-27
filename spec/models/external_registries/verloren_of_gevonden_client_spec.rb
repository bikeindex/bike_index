require "rails_helper"

module ExternalRegistries
  RSpec.describe VerlorenOfGevondenClient, type: :model do
    before do
      null_cache = ActiveSupport::Cache.lookup_store(:null_store)
      allow(Rails).to receive(:cache).and_return(null_cache)
    end

    after do
      allow(Rails).to receive(:cache).and_call_original
    end

    describe "#search" do
      context "given a valid query" do
        it "returns search results" do
          results = []

          with_json_response(page: 1) do |json|
            client = build_client(endpoint: "ez.php", response_body: json)
            results = client.search(27222)
          end

          expect(results).to be_present
          expect(results).to be_an_instance_of(Array)
          expect(results).to all(be_an_instance_of(ExternalBike))
          expect(results.map(&:description)).to all(match(/fiets/))
          expect(results.first.registry_id).to match(/F\d+\w*-.+/)
          expect(results.first.serial_number).to be_present
        end
      end

      context "given no results" do
        it "returns an empty array" do
          results = []

          with_json_response(page: 9999) do |json|
            client = build_client(endpoint: "ez.php", response_body: json)
            results = client.search(27222)
          end

          expect(results).to be_an_instance_of(Array)
          expect(results).to be_empty
        end
      end

      context "given an invalid query" do
        it "returns an empty array" do
          results = []

          with_json_response(page: 1) do |json|
            client = build_client(endpoint: "ez.php", response_body: json)
            results = client.search("")
          end

          expect(results).to be_an_instance_of(Array)
          expect(results).to be_empty
        end
      end
    end

    def build_client(endpoint:, response_body:)
      client = described_class.new

      unless ENV["LIVE_EXTERNAL_API_SPECS"] == "true"
        allow(client.conn).to(receive(:post)
          .with(endpoint)
          .and_return(double(:json, body: response_body)))
      end

      client
    end

    def with_json_response(page: 1)
      fixture = "lost_and_found_response_#{page}.json"
      filename = Rails.root.join("spec/fixtures/#{fixture}")
      json =
        if File.exist?(filename)
          JSON.parse(File.read(filename))
        else
          {}
        end

      yield json
    end
  end
end
