class StolenBike::ActivatePromotedAlertJob < ApplicationJob
  sidekiq_options retry: 4 # It will retry because of StolenBike::UpdatePromotedAlertFacebookJob

  def perform(promoted_alert_id, force_activate = false)
    promoted_alert = PromotedAlert.find(promoted_alert_id)
    return false unless promoted_alert.pending?
    return false unless promoted_alert.activateable? || force_activate

    if promoted_alert.activating_at.blank?
      new_data = promoted_alert.facebook_data || {}
      promoted_alert.update(facebook_data: new_data.merge(activating_at: Time.current.to_i))
    end

    Facebook::AdsIntegration.new.create_for(promoted_alert)

    promoted_alert.reload
    # And mark the theft alert active
    promoted_alert.update(start_at: promoted_alert.start_at_with_fallback,
      end_at: promoted_alert.calculated_end_at,
      status: "active")
    # Generally, there is information that didn't get saved when the ad was created, so enqueue update
    StolenBike::UpdatePromotedAlertFacebookJob.perform_in(15.seconds, promoted_alert.id)
  end
end
