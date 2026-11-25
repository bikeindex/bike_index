# frozen_string_literal: true

class BikebookModelsSyncJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority"

  # The index's file name is a digest of it, so a publish that changes it renames it. A manufacturer added since can
  # match models the last sync skipped. Versioned with what a row holds, so a change to it syncs without a publish
  SYNCED_KEY = ["bikebook_catalog/synced", 2]
  # Off in test, where every inline spec creating a bike would read the catalog
  SYNC_ON_BIKE_CREATION = !Rails.env.test?

  def self.frequency = 62.minutes

  # For a fresh read of the catalog's manifest, so a publish syncs without waiting on the schedule
  def self.enqueue_for(index)
    perform_async unless index.blank? || Rails.cache.read(SYNCED_KEY)&.first == index || enqueued?
  end

  # For a created bike, so a database that has never synced - eg one being seeded - doesn't wait on the schedule
  def self.enqueue_unsynced
    perform_async if SYNC_ON_BIKE_CREATION && BikebookModel.none? && !enqueued?
  end

  def perform
    index = Integrations::Bikebook::Catalog.manifest&.dig("index")
    synced = [index, Manufacturer.maximum(:updated_at)]
    return if index.blank? || Rails.cache.read(SYNCED_KEY) == synced

    models = Integrations::Bikebook::Catalog.index_models(index)
    return if models.blank?

    manufacturer_ids = Manufacturer.where(slug: models.pluck("manufacturer").uniq).pluck(:slug, :id).to_h
    rows = models.filter_map { |model| manufacturer_ids[model["manufacturer"]]&.then { row(model, it) } }
    rows.each_slice(1_000) { BikebookModel.upsert_all(it, unique_by: :catalog_id) }
    BikebookModel.where.not(catalog_id: rows.pluck(:catalog_id)).delete_all
    Rails.cache.write(SYNCED_KEY, synced)
  end

  private

  def row(model, manufacturer_id)
    {catalog_id: model["id"], manufacturer_id:, name: model["model"],
     model_slug: Slugifyer.book_slug(model["model"]), first_year: model["first_year"], final_year: model["final_year"],
     markets: [*model["markets"], *model["variants"].flat_map { it["markets"] }].uniq}
  end
end
