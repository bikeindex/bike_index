class Users::RemoveUnconfirmedJob < ScheduledJob
  prepend ScheduledJobRecorder

  REMOVE_DELAY = 2.days

  def self.frequency
    23.hours
  end

  def perform
    unconfirmed_users_to_remove.find_each { |user| user.really_destroy! }

    banned_email_domains.each do |domain|
      User.matching_domain(domain).find_each { |user| user.really_destroy! }
    end
  end

  def unconfirmed_users_to_remove
    User.where("created_at < ?", Time.current - REMOVE_DELAY).unconfirmed
  end

  def banned_email_domains
    EmailDomain.banned.pluck(:domain)
  end
end
