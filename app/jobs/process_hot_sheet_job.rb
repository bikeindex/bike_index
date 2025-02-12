class ProcessHotSheetJob < ScheduledJob
  prepend ScheduledJobRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    30.minutes
  end

  def perform(org_id = nil)
    return enqueue_workers unless org_id.present?
    hot_sheet = HotSheet.for(org_id, Time.current.to_date)
    return hot_sheet if hot_sheet&.email_success?
    hot_sheet ||= HotSheet.create!(organization_id: org_id, sheet_date: Time.current.to_date)
    hot_sheet.fetch_stolen_records
    recipient_emails = hot_sheet.fetch_recipients
    return if recipient_emails.none?

    # Postmark only allows 50 emails per sent email, so abide by that
    recipient_emails.each_slice(48).map do |permitted_recipient_emails|
      send_emails(hot_sheet, permitted_recipient_emails)
    end
  end

  def enqueue_workers
    Organization.with_enabled_feature_slugs("hot_sheet").left_joins(:hot_sheet_configuration)
      .where(hot_sheet_configurations: {is_on: true}).each do |organization|
      next unless organization.hot_sheet_configuration&.send_today_now?

      self.class.perform_async(organization.id)
    end
  end

  private

  def send_emails(hot_sheet, emails)
    pp emails
    # This is called from process_hot_sheet_worker, so it can be delivered inline
    OrganizedMailer.hot_sheet(hot_sheet, emails).deliver_now
  end

  # update(delivery_status: "delivery_success")
  #   user_email&.update_last_email_errored!(email_errored: false)
  # rescue => e
  #   update(delivery_status: "delivery_failure", delivery_error: e.class)
  #   user_email&.update_last_email_errored!(email_errored: true)

  #   raise e unless UNDELIVERABLE_ERRORS.include?(delivery_error)
end
