class ProcessHotSheetJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    30.minutes
  end

  def self.enqueue_workers
    Organization.with_enabled_feature_slugs("hot_sheet").joins(:hot_sheet_configuration)
      .merge(HotSheetConfiguration.on).each do |organization|
      next unless organization.hot_sheet_configuration&.send_today_now?

      perform_async(organization.id)
    end
  end

  def perform(org_id = nil)
    return self.class.enqueue_workers unless org_id.present?

    hot_sheets = HotSheet.for(org_id, Time.current.to_date)
    return hot_sheets if hot_sheets.all?(&:delivery_settled?)

    # Saved before any delivery, so a run that dies leaves the rest of the day's batches
    # to the next one - HotSheet.for builds them only for a day that has none
    hot_sheets.each(&:save!)
    # Bump bike cached attributes, so the email has all the info
    hot_sheets.first.fetch_stolen_records.each { it.bike.update(updated_at: Time.current) }
    # Deliver every batch before raising, so one failure doesn't block the rest
    errors = hot_sheets.filter_map { delivery_error(it) }
    raise errors.first if errors.any?
  end

  private

  # Returns the batch's error rather than raising it, so the rest still go out - and nil
  # for a batch that delivered, which is what keeps it out of the errors
  def delivery_error(hot_sheet)
    HotSheet.track_email_delivery(hot_sheet) do
      OrganizedMailer.hot_sheet(hot_sheet).deliver_now if hot_sheet.recipient_ids.any?
    end
    nil
  rescue => e
    e
  end
end
