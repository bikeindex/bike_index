class ImpoundUpdateBikeWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform(impound_record_id)
    impound_record = ImpoundRecord.find(impound_record_id)
    impound_record.impound_record_updates.unresolved.each do |impound_record_update|
      if impound_record_update.kind == "sold"
        # DO SOME STUFF
      elsif impound_record_update.kind == "removed_from_bike_index"
        impound_record.bike.destroy
      end
      impound_record_update.update(resolved: true)
    end
    impound_record.bike.update(updated_at: Time.current)
  end
end
