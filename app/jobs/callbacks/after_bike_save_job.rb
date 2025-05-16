# This will replace WebhookRunner - which is brittle and not flexible enough for what I'm looking for now
# I need to refactor that, but I don't want to right now because I don't want to break existing stuff yet

class Callbacks::AfterBikeSaveJob < ApplicationJob
  sidekiq_options retry: false

  POST_URL = ENV["BIKE_WEBHOOK_URL"]
  AUTH_TOKEN = ENV["BIKE_WEBHOOK_AUTH_TOKEN"]

  def perform(bike_id, skip_user_update = false, resave_bike = false)
    bike = Bike.unscoped.where(id: bike_id).first
    return true unless bike.present?
    bike.update(updated_at: Time.current) && bike.reload if resave_bike
    bike.load_external_images
    update_matching_partial_registrations(bike)
    DuplicateBikeFinderJob.perform_async(bike_id)
    if bike.present? && bike.listing_order != bike.calculated_listing_order
      bike.update_attribute :listing_order, bike.calculated_listing_order
    end
    create_user_registration_organizations(bike)
    update_ownership(bike)
    unless skip_user_update
      # Update the user to update any user alerts relevant to bikes
      ::Callbacks::AfterUserChangeJob.new.perform(bike.owner.id, bike.owner.reload, true) if bike.owner.present?
    end
    bike.bike_versions.each do |bike_version|
      bike_version.set_calculated_attributes
      bike_version.save if bike_version.changed?
    end
    bike.update_column :credibility_score, bike.credibility_scorer.score
    if FindOrCreateModelAuditJob.enqueue_for?(bike)
      FindOrCreateModelAuditJob.perform_async(bike.id)
    end
    return true unless bike.status_stolen? # For now, only hooking on stolen bikes

    StolenBike::AfterStolenRecordSaveJob.perform_async(bike.current_stolen_record_id)
    post_bike_to_webhook(serialized(bike))
  end

  def post_bike_to_webhook(post_body)
    return true unless POST_URL.present?
    Faraday.new(url: POST_URL).post do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = post_body.to_json
    end
  end

  def serialized(bike)
    {
      auth_token: AUTH_TOKEN,
      bike: BikeV2ShowSerializer.new(bike, root: false).as_json,
      update: bike.created_at > Time.current - 30.seconds
    }
  end

  def update_matching_partial_registrations(bike)
    return true unless bike.created_at > Time.current - 5.minutes # skip unless new bike
    matches = BParam.partial_registrations.without_bike.where("email ilike ?", "%#{bike.owner_email}%")
      .reorder(:created_at)
    if matches.count > 1
      # Try to make it a little more accurate lookup
      best_matches = matches.select { |b_param| b_param.manufacturer_id == bike.manufacturer_id }
      matches = best_matches if matches.any?
    end
    matching_b_param = matches.last # Because we want the last created
    return true unless matching_b_param.present?
    matching_b_param.update(created_bike_id: bike.id)
    # Only set ownership
    ownership = bike.current_ownership
    if ownership.present? && ownership.origin == "web" && ownership.organization_id.blank?
      ownership.organization_id = matching_b_param.organization_id
      ownership.origin = matching_b_param.origin if (Ownership.origins - ["web"]).include?(matching_b_param.origin)
      ownership.save
      if matching_b_param.organization_id.present?
        bike.update(creation_organization_id: matching_b_param.organization_id)
        bike.bike_organizations.create(organization_id: matching_b_param.organization_id)
      end
    end
  end

  # Bump registration_info attributes on ownerships
  def update_ownership(bike)
    bike.current_ownership&.update(updated_at: Time.current)
  end

  def create_user_registration_organizations(bike)
    return if bike.reload.user.blank?
    bike.bike_organizations.each do |bike_organization|
      # If there is notification that is graduated for the organization, don't create new reg organizations
      organization = bike_organization.organization
      next if organization.blank? || UserRegistrationOrganization.unscoped
        .where(user_id: bike.user.id, organization_id: organization.id).any?
      user_registration_organization = UserRegistrationOrganization.new(user_id: bike.user.id, organization_id: organization.id)
      user_registration_organization.all_bikes = organization.user_registration_all_bikes?
      user_registration_organization.can_not_edit_claimed = bike_organization.can_not_edit_claimed
      user_registration_organization.set_initial_registration_info
      user_registration_organization.update(skip_after_user_change_worker: true)
    end
    bike.reload
  end
end
