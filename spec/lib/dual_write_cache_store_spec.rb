require "rails_helper"

RSpec.describe DualWriteCacheStore do
  let(:primary) { ActiveSupport::Cache::MemoryStore.new }
  let(:secondary) { ActiveSupport::Cache::MemoryStore.new }
  let(:store) { described_class.new(primary:, secondary:) }

  describe "#write" do
    it "writes to both backends" do
      store.write("key", "value")
      expect(primary.read("key")).to eq("value")
      expect(secondary.read("key")).to eq("value")
    end
  end

  describe "#read" do
    before do
      primary.write("primary-only", "from-primary")
      secondary.write("secondary-only", "from-secondary")
    end

    it "reads only from primary" do
      expect(store.read("primary-only")).to eq("from-primary")
      expect(store.read("secondary-only")).to be_nil
    end
  end

  describe "#fetch" do
    context "when the key is missing" do
      it "yields, writes to both, returns the value" do
        result = store.fetch("k") { "computed" }
        expect(result).to eq("computed")
        expect(primary.read("k")).to eq("computed")
        expect(secondary.read("k")).to eq("computed")
      end
    end

    context "when the key is in primary" do
      before { primary.write("k", "cached") }

      it "returns the cached value without yielding" do
        expect { |b| store.fetch("k", &b) }.not_to yield_control
        expect(store.fetch("k") { "ignored" }).to eq("cached")
      end
    end
  end

  describe "#delete" do
    before do
      primary.write("k", "v")
      secondary.write("k", "v")
    end

    it "deletes from both backends" do
      store.delete("k")
      expect(primary.read("k")).to be_nil
      expect(secondary.read("k")).to be_nil
    end
  end

  describe "#increment" do
    before do
      primary.write("counter", 0, raw: true)
      secondary.write("counter", 0, raw: true)
    end

    it "increments both backends" do
      store.increment("counter", 1)
      expect(primary.read("counter").to_i).to eq(1)
      expect(secondary.read("counter").to_i).to eq(1)
    end
  end

  context "when secondary raises" do
    let(:secondary) do
      Class.new(ActiveSupport::Cache::MemoryStore) {
        def write(*, **) = raise "boom"
        def delete(*, **) = raise "boom"
      }.new
    end

    it "swallows the secondary error and still writes to primary" do
      expect { store.write("k", "v") }.not_to raise_error
      expect(primary.read("k")).to eq("v")
    end

    it "still deletes from primary" do
      primary.write("k", "v")
      expect { store.delete("k") }.not_to raise_error
      expect(primary.read("k")).to be_nil
    end
  end
end
