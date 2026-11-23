# frozen_string_literal: true

class BikebookModelsSyncJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority"

  # The index's file name is a digest of it, so a publish that changes it renames it
  SYNCED_INDEX_KEY = "bikebook_catalog/synced_index"

  def self.frequency = 62.minutes

  def perform
    index = Integrations::Bikebook::Catalog.manifest&.dig("index")
    return if index.blank? || Rails.cache.read(SYNCED_INDEX_KEY) == index

    rows = Integrations::Bikebook::Catalog.index_models(index)&.map { row(it) }
    return if rows.blank?

    rows.each_slice(1_000) { BikebookModel.upsert_all(it, unique_by: :catalog_id) }
    BikebookModel.where.not(catalog_id: rows.pluck(:catalog_id)).delete_all
    Rails.cache.write(SYNCED_INDEX_KEY, index)
  end

  private

  # TODO: once the published catalog is at 2.0.0, whose manufacturer slugs are dashed, drop the tr
  def row(model)
    {catalog_id: model["id"], manufacturer_slug: model["manufacturer"].tr("_", "-"), name: model["model"],
     model_slug: Slugifyer.book_slug(model["model"]), first_year: model["first_year"], final_year: model["final_year"],
     markets: model["markets"].to_a, variants: model["variants"].to_a.map { it.slice("id", "markets") }}
  end
end
