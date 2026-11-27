# frozen_string_literal: true

class BikebookModelsDataSyncJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority"

  def self.frequency = 62.minutes

  def perform
    blocks = Integrations::Bikebook::Catalog.manifest&.dig("blocks")
    return if blocks.blank?

    stale_files(blocks).each do |file|
      # A file the catalog doesn't answer ends the run, as the rest likely wouldn't answer either
      records = Integrations::Bikebook::Catalog.file_models(file) || break
      records.group_by { |key, _| Integrations::Bikebook::Catalog.base_id(key) }.then do |by_model|
        BikebookModel.where(catalog_id: by_model.keys).find_each { it.update!(data: by_model[it.catalog_id].to_h, data_file: file) }
      end
    end
  end

  private

  # A block's file name is a digest of it, so a publish that changes the block renames it. A model the index sync added
  # to a block already synced has no data_file
  def stale_files(blocks)
    BikebookModel.pluck(:catalog_id, :data_file).filter_map do |catalog_id, data_file|
      blocks[catalog_id[Integrations::Bikebook::Catalog::MODEL_ID, 1]].then { it unless it == data_file }
    end.uniq
  end
end
