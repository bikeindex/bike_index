class AfterUserChangeWorker < ApplicationWorker
  sidekiq_options retry: false

  def perform(user_id, user = nil)
    user ||= User.find_by_id(user_id)
    return false unless user.present?

    add_phones_for_verification(user)

    associate_feedbacks(user)

    # Create a new mailchimp datum if it's deserved
    MailchimpDatum.find_and_update_or_create_for(user)

    current_alerts = user_alert_slugs(user)
    unless user.alert_slugs == current_alerts
      user.update_attributes(alert_slugs: current_alerts, skip_update: true)
    end
  end

  def user_alert_slugs(user)
    (update_user_alerts(user) + UserAlert.where(user_id: user.id).active.distinct.pluck(:kind))
      .uniq.sort
  end

  def update_user_alerts(user)
    alerts = []
    alerts << "unassigned_bike_org" if alert_for_unassigned_bike_org(user)

    # Add user phone alerts
    user.user_phones.each do |user_phone|
      UserAlert.update_phone_waiting_confirmation(user, user_phone)
    end

    # Ignore alerts below for superusers
    return alerts if user.superuser

    if user.rough_stolen_bikes.any? { |b| b&.current_stolen_record&.theft_alert_missing_photo? }
      alerts << "theft_alert_without_photo"
    end

    return alerts if user.memberships.admin.any?

    if user.rough_stolen_bikes.any? { |b| b&.current_stolen_record&.without_location? }
      alerts << "stolen_bikes_without_locations"
    end

    (alerts + UserAlert.where(user_id: user.id).active.distinct.pluck(:kind)).sort.uniq
  end

  def associate_feedbacks(user)
    Feedback.no_user.where(email: user.confirmed_emails).each { |f|
      f.update(user_id: user.id)
    }
  end

  def add_phones_for_verification(user)
    return false if user.phone.blank?
    return false if user.user_phones.unscoped.where(phone: user.phone).present?
    user_phone = user.user_phones.create!(phone: user.phone)
    # Run this in the same process, rather than a different worker, so we update the user alerts
    UserPhoneConfirmationWorker.new.perform(user_phone.id, true)

    user.reload
    true
  end

  def alert_for_unassigned_bike_org(user)
    # user.bike_organizations.alert_on_unassigned_bike
  end
end
