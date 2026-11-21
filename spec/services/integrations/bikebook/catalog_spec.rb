# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Bikebook::Catalog do
  include ActiveSupport::Testing::TimeHelpers

  let(:manifest_url) { "#{described_class::URL}#{described_class::MANIFEST}" }
  let(:fixture_manifest) { JSON.parse(BikebookCatalogHelpers::FIXTURES.join(described_class::MANIFEST).read) }

  before { stub_bikebook_catalog }

  # The catalog as it is once it publishes again: a new vocabulary, and Segway's 2025 block with a new description
  def publish_update
    block = JSON.parse(BikebookCatalogHelpers::FIXTURES.join("models/segway/2025.json").read)
    block["models"]["m/segway/2025/gt3_pro"]["description"] = "Updated"
    WebMock.stub_request(:get, "#{described_class::URL}models/segway/2025.v2.json").to_return(body: block.to_json)
    updated = fixture_manifest.merge("vocabulary" => "vocabulary.v2.json")
    updated["blocks"] = updated["blocks"].merge("segway/2025" => "models/segway/2025.v2.json")
    WebMock.stub_request(:get, manifest_url).to_return(body: updated.to_json)
  end

  describe "manifest" do
    it "is read once a request" do
      expect(described_class.manifest["format"]).to eq described_class::FORMAT
      Rails.cache.clear
      WebMock.stub_request(:get, manifest_url).to_return(status: 503)

      expect(described_class.manifest["format"]).to eq described_class::FORMAT
      described_class::Reads.reset
      expect(described_class.manifest).to be_nil
    end

    it "is cached with the head, from the same read" do
      expect(described_class.head).to match("format" => described_class::FORMAT, "vocabulary" => "vocabulary.json", "digest" => a_string_matching(/\A\h{64}\z/))
      WebMock.stub_request(:get, manifest_url).to_return(status: 503)
      described_class::Reads.reset

      expect(described_class.manifest["blocks"]).to eq fixture_manifest["blocks"]
    end

    it "takes up a catalog update within 5 minutes, the head with it" do
      digest = described_class.head["digest"]
      publish_update
      described_class::Reads.reset
      expect(described_class.head["vocabulary"]).to eq "vocabulary.json"

      travel(5.minutes + 1.second) do
        described_class::Reads.reset
        expect(described_class.head).to include("vocabulary" => "vocabulary.v2.json")
        expect(described_class.head["digest"]).to_not eq digest
        expect(described_class.manifest.dig("blocks", "segway/2025")).to eq "models/segway/2025.v2.json"
      end
    end

    context "while the catalog doesn't answer" do
      before { WebMock.stub_request(:get, manifest_url).to_return(status: 503) }

      it "is read again once it does" do
        expect(described_class.manifest).to be_nil
        stub_bikebook_catalog
        expect(described_class.manifest["format"]).to eq described_class::FORMAT
      end
    end
  end

  describe "vehicle" do
    let(:block_url) { "#{described_class::URL}models/segway/2025.json" }

    it "caches the model's title, description and image, without its block, and reads neither again" do
      expect(described_class.vehicle("m/segway/2025/gt3_pro")).to match(title: "Segway GT3 Pro",
        description: a_string_starting_with("Experience elite performance"), image_url: "https://bikebook.bikeindex.org/segway/2025/gt3_pro.png")
      expect(Rails.cache.exist?(["bikebook_catalog/file", "models/segway/2025.json"])).to be false
      Rails.cache.delete(["bikebook_catalog/manifest", described_class::MANIFEST])
      WebMock.stub_request(:get, /#{Regexp.escape(described_class::URL)}/o).to_return(status: 503)
      described_class::Reads.reset

      expect(described_class.vehicle("m/segway/2025/gt3_pro")).to include(title: "Segway GT3 Pro")
    end

    it "takes up a catalog update within 5 minutes" do
      expect(described_class.vehicle("m/segway/2025/gt3_pro")[:description]).to start_with("Experience elite performance")
      publish_update

      travel(5.minutes + 1.second) do
        described_class::Reads.reset
        expect(described_class.vehicle("m/segway/2025/gt3_pro")[:description]).to eq "Updated"
      end
    end

    it "is nil for a model the catalog hasn't" do
      expect(described_class.vehicle("m/segway/2025/gt9")).to be_nil
      expect(described_class.vehicle("m/nobody/2025/gt9")).to be_nil
    end

    context "with its block unreachable" do
      before { WebMock.stub_request(:get, block_url).to_return(status: 503) }

      it "raises Unreachable" do
        expect { described_class.vehicle("m/segway/2025/gt3_pro") }.to raise_error(described_class::Unreachable)
      end
    end
  end
end
