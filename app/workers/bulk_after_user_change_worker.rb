# Actually is a migration job for #3131
class BulkAfterUserChangeWorker < AfterUserChangeWorker
  sidekiq_options retry: false, queue: "low_priority"

  def self.migration_at
    Time.at(1641522364)
  end

  def self.enqueue?
    # Skip if the queue is backing up
    !ScheduledWorker.enqueued?
  end

  def self.bikes
    Bike.reorder(updated_at: :desc).where("bikes.updated_at < ?", migration_at)
  end

  def self.users
    User.reorder(updated_at: :desc).where("users.updated_at < ?", migration_at)
  end

  def self.ownerships
    Ownership.reorder(updated_at: :desc).where("ownerships.updated_at < ?", migration_at)
  end

  def perform(user_id, user = nil, skip_bike_update = false)
    user ||= User.find_by_id(user_id)
    return false if user.blank? || user.updated_at > self.class.migration_at
    resave_bikes = create_user_registration_organizations(user)
    user.reload.update(updated_at: Time.current, skip_update: true)

    if resave_bikes
      # Good enough to do the first 20 for now, I think
      user.bikes.limit(20).each do |bike|
        bike.update(updated_at: Time.current)
        bike.current_ownership&.update(updated_at: Time.current)
      end
    end
  end

  def create_user_registration_organizations(user)
    resave_bikes = false
    # This doesn't work perfectly - but it gets close enough. Not the best query, can't actually call things like .count
    # But - it gets us the organization_id unique bike organizations for a user
    BikeOrganization.unscoped.where(bike_id: user.bike_ids).select("DISTINCT ON (organization_id) *").each do |bo|
      next if UserRegistrationOrganization.unscoped
        .where(user_id: user.id, organization_id: bo.organization_id).any?
      next if bo.organization.blank?
      resave_bikes ||= true
      user_registration_organization = UserRegistrationOrganization.new(user_id: user.id, organization_id: bo.organization_id)
      user_registration_organization.all_bikes = bo.organization.user_registration_all_bikes?
      user_registration_organization.can_not_edit_claimed = bo.can_not_edit_claimed
      user_registration_organization.set_initial_registration_info
      user_registration_organization.update(skip_after_user_change_worker: true)
    end
    resave_bikes
  end
end
