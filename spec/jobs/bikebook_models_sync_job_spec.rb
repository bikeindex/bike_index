# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikebookModelsSyncJob, type: :job do
  let(:instance) { described_class.new }
  let!(:dropped) do
    BikebookModel.create!(catalog_id: "m/specialized/2020/dropped", manufacturer_slug: "specialized", name: "Dropped",
      model_slug: "dropped", first_year: 2020)
  end
  before { stub_bikebook_catalog }

  it "syncs the index's models, deleting those it dropped, once for each index" do
    instance.perform

    expect(BikebookModel.count).to eq 39
    expect(BikebookModel.find_by(catalog_id: "m/specialized/2025/haul_st")).to have_attributes(manufacturer_slug: "specialized",
      name: "Haul ST", model_slug: "haul_st", first_year: 2025, final_year: nil, markets: ["US"],
      variants: [{"id" => "m/specialized/2025/haul_st_ca", "markets" => ["CA"]}])
    expect(BikebookModel.find_by(catalog_id: dropped.catalog_id)).to be_nil

    BikebookModel.where(manufacturer_slug: "aventon").delete_all
    instance.perform
    expect(BikebookModel.where(manufacturer_slug: "aventon").count).to eq 0

    Rails.cache.delete(described_class::SYNCED_INDEX_KEY)
    instance.perform
    expect(BikebookModel.where(manufacturer_slug: "aventon").count).to eq 21
  end

  context "with the catalog unreachable" do
    before { stub_bikebook_catalog(status: 500) }

    it "keeps the models it has" do
      instance.perform

      expect(BikebookModel.pluck(:catalog_id)).to eq [dropped.catalog_id]
      expect(Rails.cache.read(described_class::SYNCED_INDEX_KEY)).to be_nil
    end
  end
end
