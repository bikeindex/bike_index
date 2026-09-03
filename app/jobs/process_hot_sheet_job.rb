class ProcessHotSheetJob < ScheduledJob
  prepend ScheduledJobRecorder

  # Postmark only allows 50 emails per sent email
  # So split into separate hot sheets, all rendering the same bikes
  RECIPIENTS_PER_EMAIL = 48

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

    hot_sheet = HotSheet.for(org_id, Time.current.to_date)
    return hot_sheet if hot_sheet&.email_success?

    hot_sheet ||= HotSheet.create!(organization_id: org_id, sheet_date: Time.current.to_date)
    # Bump bike cached attributes, so the email has all the info
    hot_sheet.fetch_stolen_records.each { it.bike.update(updated_at: Time.current) }
    # Always at least one slice, so a sheet with nobody to email is still marked delivered
    recipient_id_slices = hot_sheet.hot_sheet_configuration.current_recipient_ids
      .each_slice(RECIPIENTS_PER_EMAIL).to_a.presence || [[]]

    # Everything a batch's sheet shares with the others - notably not the delivery status
    sheet_attributes = {organization: hot_sheet.organization, sheet_date: hot_sheet.sheet_date,
                        stolen_record_ids: hot_sheet.stolen_record_ids}
    # Deliver every batch before raising, so one failure doesn't block the rest
    errors = recipient_id_slices.filter_map.with_index do |recipient_ids, index|
      sheet = index.zero? ? hot_sheet : HotSheet.new(sheet_attributes)
      sheet.recipient_ids = recipient_ids
      deliver_email(sheet)
    end
    raise errors.first if errors.any?
  end

  private

  def deliver_email(hot_sheet)
    hot_sheet.track_email_delivery do
      OrganizedMailer.hot_sheet(hot_sheet).deliver_now if hot_sheet.recipient_ids.any?
    end
  end
end
