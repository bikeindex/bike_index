class ActivateTheftAlertWorker < ApplicationWorker
  def perform(theft_alert_id, force_activate: false)
    theft_alert = TheftAlert.find(theft_alert_id)
    return false unless theft_alert.pending?
    unless force_activate
      return false unless theft_alert.activateable?
    end
    Facebook::AdsIntegration.new.create_for(theft_alert)
    # And mark the theft alert active
    theft_alert.update(begin_at: theft_alert.calculated_begin_at,
                       end_at: theft_alert.calculated_end_at,
                       status: "active")
  end
end
