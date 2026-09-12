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

    # Bump bike cached attributes, so the email has all the info
    hot_sheets.first.fetch_stolen_records.each { it.bike.update(updated_at: Time.current) }
    # Deliver every batch before raising, so one failure doesn't block the rest
    errors = hot_sheets.filter_map { deliver_email(it) }
    raise errors.first if errors.any?
  end

  private

  def deliver_email(hot_sheet)
    hot_sheet.track_email_delivery do
      OrganizedMailer.hot_sheet(hot_sheet).deliver_now if hot_sheet.recipient_ids.any?
    end
    nil
  rescue => e
    e
  end
end
