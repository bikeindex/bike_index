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
    Organization.with_enabled_feature_slugs("hot_sheet").left_joins(:hot_sheet_configuration)
      .where(hot_sheet_configurations: {is_on: true}).each do |organization|
      next unless organization.hot_sheet_configuration&.send_today_now?

      perform_async(organization.id)
    end
  end

  def perform(org_id = nil)
    return self.class.enqueue_workers unless org_id.present?

    hot_sheet = HotSheet.for(org_id, Time.current.to_date)
    return hot_sheet if hot_sheet&.email_success?

    hot_sheet ||= HotSheet.create!(organization_id: org_id, sheet_date: Time.current.to_date)
    # Bump bike cached attributes, to be sure the email has all the info. Once per sheet -
    hot_sheet.fetch_stolen_records.each { it.bike.update(updated_at: Time.current) }
    hot_sheet.fetch_recipients
    recipient_id_slices = hot_sheet.recipient_ids.each_slice(RECIPIENTS_PER_EMAIL).to_a
    return if recipient_id_slices.none?

    recipient_id_slices.each_with_index do |recipient_ids, index|
      sheet = index.zero? ? hot_sheet : hot_sheet.dup
      sheet.update!(recipient_ids:)
      send_email(sheet)
    end
  end

  private

  def send_email(hot_sheet)
    # This is called from process_hot_sheet_job, so it can be delivered inline
    OrganizedMailer.hot_sheet(hot_sheet).deliver_now
  end

  # update(delivery_status: "delivery_success")
  #   user_email&.update_last_email_errored!(email_errored: false)
  # rescue => e
  #   update(delivery_status: "delivery_failure", delivery_error: e.class)
  #   user_email&.update_last_email_errored!(email_errored: true)

  #   raise e unless UNDELIVERABLE_ERRORS.include?(delivery_error)
end
