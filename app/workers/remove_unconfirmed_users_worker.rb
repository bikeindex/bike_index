class RemoveUnconfirmedUsersWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  REMOVE_DELAY = 2.days

  def self.frequency
    23.hours
  end

  def perform
    unconfirmed_to_remove.find_each { |user| user.really_destroy! }
    banned_email_domain_users.find_each { |user| user.really_destroy! }
  end

  def unconfirmed_to_remove
    User.where("created_at < ?", Time.current - REMOVE_DELAY)
      .unconfirmed
  end

  def banned_email_domain_users
    User.none
  end
end
