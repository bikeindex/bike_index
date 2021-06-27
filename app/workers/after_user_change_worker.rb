class AfterUserChangeWorker < ApplicationWorker
  sidekiq_options retry: false

  def perform(user_id, user = nil)
    user ||= User.find_by_id(user_id)
    return false unless user.present?

    add_phones_for_verification(user)

    associate_feedbacks(user)

    # Create a new mailchimp datum if it's deserved
    MailchimpDatum.find_and_update_or_create_for(user)

    update_user_alerts(user)
    current_alerts = user_alert_slugs(user)
    unless user.alert_slugs == current_alerts
      user.update_attributes(alert_slugs: current_alerts, skip_update: true)
    end
  end

  def user_alert_slugs(user)
    UserAlert.where(user_id: user.id).active.distinct.pluck(:kind).sort
  end

  def update_user_alerts(user)
    # Add user phone alerts
    user.user_phones.each do |user_phone|
      UserAlert.update_phone_waiting_confirmation(user: user, user_phone: user_phone)
    end

    # Ignore alerts below for superusers
    if user.superuser?
      user.user_alerts.active.ignored_superuser.each { |user_alert| user_alert.resolve! }
      return
    end

    user.bike_organizations.select { |o| o.paid_money? }.each do |organization|
      user.bikes.each do |bike|
        UserAlert.update_unassigned_bike_org(user: user, organization: organization, bike: bike)
      end
    end

    user.theft_alerts.each do |theft_alert|
      UserAlert.update_theft_alert_without_photo(user: user, theft_alert: theft_alert)
    end

    # Ignore alerts below for org admins, otherwise they might get a lot of useless ones
    if user.memberships.admin.any?
      user.user_alerts.active.ignored_admin_member.each { |user_alert| user_alert.resolve! }
      return
    end

    user.rough_stolen_bikes.each do |bike|
      UserAlert.update_stolen_bike_without_location(user: user, bike: bike)
    end
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
