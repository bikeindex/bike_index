# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikebookModelsSyncJob, type: :job do
  let(:instance) { described_class.new }
  let!(:specialized) { FactoryBot.create(:manufacturer, name: "Specialized") }
  let!(:aventon) { FactoryBot.create(:manufacturer, name: "Aventón") }
  let!(:kris_holm) { FactoryBot.create(:manufacturer, name: "Kris Holm") }
  let!(:dropped) do
    BikebookModel.create!(catalog_id: "m/specialized/2020/dropped", manufacturer: specialized, name: "Dropped",
      model_slug: "dropped", first_year: 2020)
  end
  let!(:returned) do
    BikebookModel.create!(catalog_id: "m/specialized/2025/haul-st", manufacturer: specialized, name: "Haul ST",
      model_slug: "haul_st", first_year: 2025, deleted_at: Time.current)
  end
  before { stub_bikebook_catalog }

  it "syncs the index's models of the manufacturers it has, deleting those it dropped, once for each index and manufacturer" do
    instance.perform
    # Soft deleted, as vehicle specifications keep pointing at them
    expect(dropped.reload.deleted_at).to be_present
    expect(returned.reload.deleted_at).to be_nil

    expect(BikebookModel.distinct.pluck(:manufacturer_id)).to match_array [specialized.id, aventon.id, kris_holm.id]
    expect(BikebookModel.count).to eq 30
    expect(BikebookModel.find_by(catalog_id: "m/specialized/2025/haul-st")).to have_attributes(manufacturer: specialized,
      name: "Haul ST", model_slug: "haul-st", first_year: 2025, final_year: nil, markets: ["US", "CA"])
    expect(BikebookModel.find_by(catalog_id: "m/kris-holm/2023/kh24").manufacturer).to eq kris_holm
    expect(BikebookModel.find_by(catalog_id: dropped.catalog_id)).to be_nil

    BikebookModel.where(manufacturer: aventon).delete_all
    instance.perform
    expect(BikebookModel.where(manufacturer: aventon).count).to eq 0

    segway = FactoryBot.create(:manufacturer, name: "Segway")
    instance.perform
    expect(BikebookModel.where(manufacturer: aventon).count).to eq 21
    expect(BikebookModel.where(manufacturer: segway).pluck(:catalog_id)).to eq ["m/segway/2025/gt3-pro"]
  end

  describe "blocks" do
    let(:block_url) { %r{\A#{Regexp.escape(Integrations::Bikebook::Catalog::URL)}models/}o }
    let(:haul_st) { BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st") }
    def expect_block_reads(times) = WebMock::API.assert_requested(:get, block_url, times:)

    before { WebMock.reset_executed_requests! }

    it "syncs each model's records from its block, reading only the blocks a publish changed" do
      instance.perform
      expect(BikebookModel.where(data: nil).count).to eq 0
      expect(haul_st.data_file).to eq "models/specialized/2025.json"
      expect(haul_st.data.keys).to match_array(["m/specialized/2025/haul-st", "m/specialized/2025/haul-st@CA"])
      expect_block_reads(BikebookModel.distinct.count(:data_file))

      WebMock.reset_executed_requests!
      instance.perform
      expect_block_reads(0)

      FactoryBot.create(:manufacturer, name: "Segway")
      stub_bikebook_catalog_update
      Rails.cache.clear
      Integrations::Bikebook::Catalog::Reads.reset
      instance.perform
      expect_block_reads(1)
      gt3_pro = BikebookModel.find_by!(catalog_id: "m/segway/2025/gt3-pro")
      expect(gt3_pro.data_file).to eq "models/segway/2025.v2.json"
      expect(gt3_pro.market_data["description"]).to eq "Updated"
    end

    context "with a model added to a block already synced" do
      it "reads the block again" do
        instance.perform
        haul_st.update!(data: nil, data_file: nil)

        WebMock.reset_executed_requests!
        instance.perform
        expect_block_reads(1)
        expect(haul_st.reload.data_file).to eq "models/specialized/2025.json"
      end
    end

    context "with a block the catalog doesn't answer" do
      it "keeps the data it has, reading no block past it" do
        instance.perform
        BikebookModel.update_all(data_file: nil)
        Rails.cache.delete(described_class::SYNCED_MANIFEST_KEY)
        WebMock.stub_request(:get, block_url).to_return(status: 500)

        WebMock.reset_executed_requests!
        instance.perform
        expect_block_reads(1)
        expect(BikebookModel.where(data: nil).count).to eq 0
        expect(Rails.cache.read(described_class::SYNCED_MANIFEST_KEY)).to be_nil
        expect(described_class.locked_for?(nil)).to be false
      end
    end
  end

  context "while another run holds the lock" do
    it "syncs nothing" do
      described_class.new.with_redlock(nil) { instance.perform }
      expect(BikebookModel.pluck(:catalog_id)).to eq [dropped.catalog_id]
    end

    context "once another run takes it partway through" do
      it "stops at the next block, leaving the other run its lock" do
        instance.perform
        BikebookModel.update_all(data_file: nil)
        Rails.cache.delete(described_class::SYNCED_MANIFEST_KEY)
        key = described_class.redlock_key(nil)
        other_lock = nil
        WebMock.stub_request(:get, %r{\A#{Regexp.escape(Integrations::Bikebook::Catalog::URL)}models/}o).to_return do |request|
          Redis.new(url: Bikeindex::Application.config.redis_default_url).del(key)
          other_lock ||= described_class.new_lock_manager.lock(key, 10_000)
          {body: BikebookCatalogHelpers::FIXTURES.join(request.uri.path.delete_prefix(URI(Integrations::Bikebook::Catalog::URL).path)).read}
        end

        instance.perform
        expect(BikebookModel.distinct.where.not(data_file: nil).count(:data_file)).to eq 1
        expect(Rails.cache.read(described_class::SYNCED_MANIFEST_KEY)).to be_nil
        expect(described_class.locked_for?(nil)).to be true
        described_class.new_lock_manager.unlock(other_lock)
      end
    end
  end

  describe "enqueue_for" do
    it "is enqueued by a manifest read of a publish it hasn't synced" do
      Integrations::Bikebook::Catalog.manifest
      expect(described_class.jobs.count).to eq 1

      described_class.drain
      synced = Rails.cache.read(described_class::SYNCED_MANIFEST_KEY)
      expect(synced).to be_present
      stub_bikebook_catalog
      Rails.cache.write(described_class::SYNCED_MANIFEST_KEY, synced)
      Integrations::Bikebook::Catalog.manifest
      expect(described_class.jobs.count).to eq 0
    end
  end

  describe "enqueue_unsynced" do
    before { stub_const("#{described_class}::SYNC_ON_BIKE_CREATION", true) }
    let(:bike_params) do
      {serial_number: "XYZ", manufacturer_id: specialized.id, primary_frame_color_id: FactoryBot.create(:color).id,
       owner_email: "owner@example.com"}
    end
    let(:b_param) { BParam.create(creator: FactoryBot.create(:user), params: {bike: bike_params}) }

    it "is enqueued by a bike's creation until the models have synced" do
      BikebookModel.delete_all
      expect(BikeServices::Creator.new.create_bike(b_param).id).to be_present
      expect(described_class.jobs.count).to eq 1

      described_class.drain
      expect(BikebookModel.count).to eq 30
      described_class.enqueue_unsynced
      expect(described_class.jobs.count).to eq 0
    end
  end

  context "with the catalog unreachable" do
    before { stub_bikebook_catalog(status: 500) }

    it "keeps the models it has" do
      instance.perform

      expect(BikebookModel.pluck(:catalog_id)).to eq [dropped.catalog_id]
      expect(Rails.cache.read(described_class::SYNCED_KEY)).to be_nil
    end
  end
end
