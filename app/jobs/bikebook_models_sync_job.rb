# frozen_string_literal: true

class BikebookModelsSyncJob < ScheduledJob
  include Sidekiq::IterableJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority"

  # The index's file name is a digest of it, so a publish that changes it renames it. A manufacturer added since can
  # match models the last sync skipped. Versioned with what a row holds, so a change to it syncs without a publish
  SYNCED_KEY = ["bikebook_catalog/synced", 3]
  # The digest of the manifest whose index and blocks have all synced
  SYNCED_MANIFEST_KEY = "bikebook_catalog/synced_manifest"
  # Off in test, where every inline spec creating a bike would read the catalog
  SYNC_ON_BIKE_CREATION = !Rails.env.test?
  # A first sync of the blocks runs for minutes, through manifest reads that would each start another. Renewed with each
  # block, so a run that dies holds it briefly
  LOCK_DURATION = 10.minutes

  def self.frequency = 62.minutes

  # For a fresh read of the catalog's manifest, so a publish syncs without waiting on the schedule
  def self.enqueue_for(digest)
    perform_async unless Rails.cache.read(SYNCED_MANIFEST_KEY) == digest || enqueued?
  end

  # For a created bike, so a database that has never synced - eg one being seeded - doesn't wait on the schedule
  def self.enqueue_unsynced
    perform_async if SYNC_ON_BIKE_CREATION && BikebookModel.none? && !enqueued?
  end

  def build_enumerator(cursor:)
    return unless (@redlock = renewable_redlock(nil, LOCK_DURATION))

    # Before the manifest, as reading a manifest that's expired writes a fresh head too
    @digest = Integrations::Bikebook::Catalog.head&.dig("digest")
    manifest = Integrations::Bikebook::Catalog.manifest
    @blocks = manifest["blocks"] if manifest.present? && sync_index(manifest["index"])
    # Not from `cursor`: a synced block drops out of stale_files, so a resumed run starts on what's left
    (@blocks ? stale_files(@blocks) : []).each
  end

  def around_iteration
    throw :abort unless renewable_redlock(nil, LOCK_DURATION, extend: @redlock)
    yield
  end

  # Past a file the catalog doesn't answer, the rest likely wouldn't either
  def each_iteration(file)
    records = Integrations::Bikebook::Catalog.file_models(file)
    throw :abort if records.nil?

    by_model = records.group_by { |key, _| Integrations::Bikebook::Catalog.base_id(key) }
    BikebookModel.where(catalog_id: by_model.keys).find_each { it.update!(data: by_model[it.catalog_id].to_h, data_file: file) }
  end

  def on_stop = lock_manager.unlock(@redlock)

  def on_complete
    Rails.cache.write(SYNCED_MANIFEST_KEY, @digest) if @blocks && stale_files(@blocks).empty?
  end

  private

  # Whether the index's models have synced
  def sync_index(index)
    synced = [index, Manufacturer.maximum(:updated_at)]
    return true if Rails.cache.read(SYNCED_KEY) == synced

    models = Integrations::Bikebook::Catalog.file_models(index)
    return false if models.blank?

    manufacturer_ids = Manufacturer.where(slug: models.pluck("manufacturer").uniq).pluck(:slug, :id).to_h
    rows = models.filter_map { |model| manufacturer_ids[model["manufacturer"]]&.then { row(model, it) } }
    rows.each_slice(1_000) { BikebookModel.upsert_all(it, unique_by: :catalog_id) }
    BikebookModel.where.not(catalog_id: rows.pluck(:catalog_id)).update_all(deleted_at: Time.current)
    Rails.cache.write(SYNCED_KEY, synced)
    true
  end

  def row(model, manufacturer_id)
    {catalog_id: model["id"], manufacturer_id:, name: model["model"],
     model_slug: Integrations::Bikebook::ModelSearch.slug(model["model"]), first_year: model["first_year"], final_year: model["final_year"],
     markets: [*model["markets"], *model["variants"].flat_map { it["markets"] }].uniq, deleted_at: nil}
  end

  # A block's file name is a digest of it, so a publish that changes the block renames it. A model the index added to a
  # block already synced has no data_file
  def stale_files(blocks)
    BikebookModel.pluck(:catalog_id, :data_file).filter_map do |catalog_id, data_file|
      blocks[catalog_id[Integrations::Bikebook::Catalog::MODEL_ID, 1]].then { it unless it == data_file }
    end.uniq
  end
end
