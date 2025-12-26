class CallbackJob::AfterUserChangeJob < ApplicationJob
  sidekiq_options retry: false

  def perform(user_id, user = nil, skip_bike_update = false)
    user ||= User.find_by_id(user_id)
    return false unless user.present?

    # Bump updated_at to bust cache
    user.update(updated_at: Time.current, skip_update: true)
    update_superuser_abilities(user)

    add_phones_for_verification(user)

    associate_feedbacks(user)

    # Create a new mailchimp datum if it's deserved
    MailchimpDatum.find_and_update_or_create_for(user)

    user.no_address = user.bike_organizations.with_enabled_feature_slugs("no_address").any?
    if !user.no_address && !user.address_set_manually # If user.address_set_manually bikes pick it up on save
      UserServices::Updator.assign_address_from_bikes(user)
    end
    user.update(skip_update: true) if user.changed?

    update_user_alerts(user)
    current_alerts = user_alert_slugs(user)
    unless user.alert_slugs == current_alerts
      user.update(alert_slugs: current_alerts, skip_update: true)
    end

    # Activate activateable theft alerts!
    user.theft_alerts.paid.where(start_at: nil).each do |theft_alert|
      next unless theft_alert.activateable?

      StolenBike::ActivateTheftAlertJob.perform_async(theft_alert.id)
    end

    process_user_registration_organizations(user)

    user.user_ban.delete if user.user_ban.present? && !user.banned?

    process_bikes(user) unless skip_bike_update
  end

  def user_alert_slugs(user)
    # Access via UserAlert query so we don't need to reload user
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

    user.theft_alerts.each do |theft_alert|
      UserAlert.update_theft_alert_without_photo(user: user, theft_alert: theft_alert)
    end

    # Ignore alerts below for org members, otherwise they might get a lot of useless ones
    if user.organization_roles.any?
      user.user_alerts.active.ignored_member.each { |user_alert| user_alert.resolve! }
      return
    end

    user.bike_organizations.select { |o| o.paid_money? }.each do |organization|
      user.bikes.each do |bike|
        UserAlert.update_unassigned_bike_org(user: user, organization: organization, bike: bike)
      end
    end

    user.bikes.status_stolen.each do |bike|
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
    # Run this in the same process, rather than a different job, so we update the user alerts
    UserPhoneConfirmationJob.new.perform(user_phone.id, true)

    user.reload
    true
  end

  def process_user_registration_organizations(user)
    # Process user_registration_organizations
    user.user_registration_organizations.order(:id).each do |u|
      # Delete dupe user_registration_organizations
      user.user_registration_organizations
        .where(organization_id: u.organization_id).where("id > ?", u.id)
        .each { |other| other.really_destroy! }
      u.create_or_update_bike_organizations
    end
  end

  def process_bikes(user)
    user.bike_ids.each { |id| ::CallbackJob::AfterBikeSaveJob.perform_async(id, true, true) }
  end

  def update_superuser_abilities(user)
    universal_abilities = user.superuser_abilities.universal.order(:id)
    if user.superuser # NOTE: NOT THE METHOD, checking attribute
      if universal_abilities.count > 1
        kept_ability = universal_abilities.first
        universal_abilities.where.not(id: kept_ability.id).destroy_all
      elsif universal_abilities.none?
        SuperuserAbility.create(user: user)
      end
    elsif universal_abilities.any?
      universal_abilities.destroy_all
    end
  end
end
