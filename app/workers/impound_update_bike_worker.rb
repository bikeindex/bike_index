class ImpoundUpdateBikeWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform(impound_record_id)
    impound_record = ImpoundRecord.find(impound_record_id)
    bike = impound_record.bike
    impound_record.impound_record_updates.unresolved.each do |impound_record_update|
      if impound_record_update.kind == "transferred_to_new_owner"
        bike.update(status: "status_with_owner",
                    owner_email: impound_record_update.transfer_email,
                    is_for_sale: false,
                    address_set_manually: false)
        ownership = bike.ownerships.create!(owner_email: impound_record_update.transfer_email,
                                            impound_record_id: impound_record.id,
                                            creator_id: impound_record_update.user_id,
                                            current: true)
        bike.ownerships.current.where.not(id: ownership.id).each { |o| o.update(current: false) }
      elsif impound_record_update.kind == "removed_from_bike_index"
        impound_record.bike.destroy
      end
      impound_record_update.update(resolved: true)
    end
    impound_record.bike&.update(updated_at: Time.current)
    impound_record.bike.reload
  end
end
