class ProcessImpoundUpdatesWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform(impound_record_id)
    impound_record = ImpoundRecord.find(impound_record_id)
    bike = impound_record.bike
    if impound_record.organized?
      matching_display_ids = ImpoundRecord.where(organization_id: impound_record.organization_id, display_id: impound_record.display_id)
      if matching_display_ids.where.not(id: impound_record.id).any?
        matching_display_ids.reorder(:id).each_with_index do |irecord, index|
          next if index == 0 # don't change the ID of the first one
          irecord.update_attributes(display_id: nil, skip_update: true)
        end
      end
    end
    claim_retrieved = nil
    # Run each impound_record_updates that hasn't been run
    impound_record.impound_record_updates.unprocessed.each do |impound_record_update|
      if impound_record_update.kind == "transferred_to_new_owner"
        bike.update(status: "status_with_owner",
                    owner_email: impound_record_update.transfer_email,
                    is_for_sale: false,
                    address_set_manually: false,
                    hidden: false)
        ownership = bike.ownerships.create!(owner_email: impound_record_update.transfer_email,
                                            impound_record_id: impound_record.id,
                                            creator_id: impound_record_update.user_id,
                                            current: true)
        bike.ownerships.current.where.not(id: ownership.id).each { |o| o.update(current: false) }
      elsif impound_record_update.kind == "removed_from_bike_index"
        impound_record.bike.destroy
      elsif impound_record_update.kind == "retrieved_by_owner" &&
          impound_record.impound_claims.approved.any?
        impound_record_update.impound_claim = impound_record.impound_claims.approved.first
        claim_retrieved = impound_record_update.impound_claim
      end
      impound_record_update.update(processed: true, skip_update: true)
    end
    impound_record.update_attributes(skip_update: true)
    # Bump the parking notification to ensure it reflects current state (resolving if relevant)
    impound_record.parking_notification&.update(updated_at: Time.current)
    if claim_retrieved.present?
      merge_impound_claim(impound_record, claim_retrieved)
    else
      # We want to mark bikes no longer user hidden when they are impounded, so that public impound pages work
      impound_record.reload
      if impound_record.unregistered_bike?
        impound_record.bike.marked_user_unhidden = true
      end
      impound_record.bike&.update(updated_at: Time.current)
      impound_record.bike&.reload
    end
  end

  def merge_impound_claim(impound_record, impound_claim)
    # Manually update, because it isn't updated
    impound_claim.update(updated_at: Time.current)
    # Mark the stolen record as recovered
    unless impound_claim.stolen_record.recovered?
      impound_claim.stolen_record.add_recovery_information(recovering_user_id: impound_record.user_id,
                                                           recovered_description: "Recovered from impounding",
                                                           index_helped_recovery: true,
                                                           can_share_recovery: true)
    end
    # TODO: make this actually merge attributes in from the bike, rather than just delete it?
    impound_record.parking_notification.bike&.delete
  end
end
