# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Bikebook::Catalog do
  include ActiveSupport::Testing::TimeHelpers

  let(:manifest_url) { "#{described_class::URL}#{described_class::MANIFEST}" }

  before { stub_bikebook_catalog }

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

      expect(described_class.manifest["blocks"]).to include("segway/2025" => "models/segway/2025.json")
    end

    it "takes up a catalog update within 5 minutes, the head with it" do
      digest = described_class.head["digest"]
      stub_bikebook_catalog_update
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

    it "is the model's title, description and image, cached without its block, and reads neither again" do
      expect(described_class.vehicle("m/segway/2025/gt3-pro")).to match(title: "Segway GT3 Pro",
        description: a_string_starting_with("Experience elite performance"), image_url: "https://bikebook.bikeindex.org/segway/2025/gt3-pro.png")
      expect(Rails.cache.exist?(["bikebook_catalog/file", "models/segway/2025.json"])).to be false
      expect(Rails.cache.exist?(["bikebook_catalog/model", described_class.head["digest"], "m/segway/2025/gt3-pro"])).to be true
      Rails.cache.delete(["bikebook_catalog/manifest", described_class::MANIFEST])
      WebMock.stub_request(:get, /#{Regexp.escape(described_class::URL)}/o).to_return(status: 503)
      described_class::Reads.reset

      expect(described_class.vehicle("m/segway/2025/gt3-pro")).to include(title: "Segway GT3 Pro")
    end

    it "takes up a catalog update within 5 minutes" do
      expect(described_class.vehicle("m/segway/2025/gt3-pro")[:description]).to start_with("Experience elite performance")
      stub_bikebook_catalog_update

      travel(5.minutes + 1.second) do
        described_class::Reads.reset
        expect(described_class.vehicle("m/segway/2025/gt3-pro")[:description]).to eq "Updated"
      end
    end

    it "is nil for a model the catalog hasn't" do
      expect(described_class.vehicle("m/segway/2025/gt9")).to be_nil
      expect(described_class.vehicle("m/nobody/2025/gt9")).to be_nil
    end

    context "with its block unreachable" do
      before { WebMock.stub_request(:get, block_url).to_return(status: 503) }

      it "raises Unreachable" do
        expect { described_class.vehicle("m/segway/2025/gt3-pro") }.to raise_error(described_class::Unreachable)
      end
    end
  end

  describe "vocabulary_dig" do
    it "caches what is at the keys alone" do
      expect(described_class.vocabulary_dig("names", "components.type")).to include("saddle" => "Saddle")
      cached = Rails.cache.read(["bikebook_catalog/vocabulary_dig", "vocabulary.json", "names", "components.type"])
      expect(cached).to eq described_class.vocabulary_dig("names", "components.type")
    end

    context "while the catalog doesn't answer" do
      before { stub_bikebook_catalog(status: 503) }

      it "is nil" do
        expect(described_class.vocabulary_dig("e_vehicle_classifications")).to be_nil
      end
    end
  end

  describe "schema_viewer" do
    it "is the file the manifest names, with its name" do
      expect(described_class.schema_viewer).to include("file" => "schema_viewer.json", "documents" => include("vehicle_model", "component"))
    end

    context "with a manifest that names none" do
      before do
        manifest = JSON.parse(BikebookCatalogHelpers::FIXTURES.join(described_class::MANIFEST).read).except("schema_viewer")
        WebMock.stub_request(:get, manifest_url).to_return(body: manifest.to_json)
      end

      it "is nil" do
        expect(described_class.schema_viewer).to be_nil
      end
    end
  end

  describe "model" do
    it "is the model's record" do
      expect(described_class.model("m/segway/2025/gt3-pro")).to include("id" => "m/segway/2025/gt3-pro", "motors" => be_present)
    end

    it "is nil for what isn't a model's id, without reading or caching anything for it" do
      WebMock.stub_request(:get, /#{Regexp.escape(described_class::URL)}/o).to_return(status: 503)

      expect(described_class.model("segway gt3")).to be_nil
      expect(described_class.model(nil)).to be_nil
      expect(Rails.cache.exist?(["bikebook_catalog/head", described_class::MANIFEST])).to be false
    end
  end
end
