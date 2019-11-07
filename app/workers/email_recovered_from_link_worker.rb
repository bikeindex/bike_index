class EmailRecoveredFromLinkWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(stolen_record_id)
    stolen_record = StolenRecord.unscoped.find(stolen_record_id)
    CustomerMailer.recovered_from_link(stolen_record).deliver_now

    promoted_alert = stolen_record.theft_alerts.active.last
    if promoted_alert.present?
      AdminMailer.theft_alert_purchased(promoted_alert, notify_of_recovery: true)
    end
  end
end
