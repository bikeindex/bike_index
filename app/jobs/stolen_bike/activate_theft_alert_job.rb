class StolenBike::ActivateTheftAlertJob < ApplicationJob
  sidekiq_options retry: 4 # It will retry because of StolenBike::UpdateTheftAlertFacebookJob

  def perform(theft_alert_id, force_activate = false)
    theft_alert = TheftAlert.find(theft_alert_id)
    return false unless theft_alert.pending?
    return false unless theft_alert.activateable? || force_activate

    if theft_alert.activating_at.blank?
      new_data = theft_alert.facebook_data || {}
      theft_alert.update(facebook_data: new_data.merge(activating_at: Time.current.to_i))
    end

    Facebook::AdsIntegration.new.create_for(theft_alert)

    theft_alert.reload
    # And mark the theft alert active
    theft_alert.update(start_at: theft_alert.start_at_with_fallback,
      end_at: theft_alert.calculated_end_at,
      status: "active")
    # Generally, there is information that didn't get saved when the ad was created, so enqueue update
    StolenBike::UpdateTheftAlertFacebookJob.perform_in(15.seconds, theft_alert.id)
  end
end
