module Users
  # Bans a likely SEO-spam public-profile (show_bikes) user — crypto/gambling link
  # farms and gibberish profiles. Enqueued from AfterUserChangeJob.
  class SeoSpamCheckJob < ApplicationJob
    sidekiq_options retry: false

    # user can be passed directly (e.g. from AfterUserChangeJob, which is already backgrounded)
    def perform(user_id, user = nil)
      user ||= User.find_by(id: user_id)
      return if user.blank? || !user.show_bikes? || user.banned?
      return unless SpamEstimator::User.estimate_user(user) > SpamEstimator::User::MARK_SPAM_PERCENT

      # UserBan#update_user_on_create bans the user and flags their bikes
      UserBan.create(user:, reason: :seo_spam)
    end
  end
end
