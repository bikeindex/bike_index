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
    expect(BikebookModelsDataSyncJob.jobs.count).to eq 1

    BikebookModel.where(manufacturer: aventon).delete_all
    instance.perform
    expect(BikebookModel.where(manufacturer: aventon).count).to eq 0

    segway = FactoryBot.create(:manufacturer, name: "Segway")
    instance.perform
    expect(BikebookModel.where(manufacturer: aventon).count).to eq 21
    expect(BikebookModel.where(manufacturer: segway).pluck(:catalog_id)).to eq ["m/segway/2025/gt3-pro"]
  end

  describe "enqueue_for" do
    it "is enqueued by a manifest read naming an index it hasn't synced" do
      Integrations::Bikebook::Catalog.manifest
      expect(described_class.jobs.count).to eq 1

      described_class.drain
      synced = Rails.cache.read(described_class::SYNCED_KEY)
      stub_bikebook_catalog
      Rails.cache.write(described_class::SYNCED_KEY, synced)
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
