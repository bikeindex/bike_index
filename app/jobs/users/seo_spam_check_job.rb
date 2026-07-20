module Users
  # Bans a likely SEO-spam public-profile (show_bikes) user — crypto/gambling link
  # farms and gibberish profiles. Enqueued from AfterUserChangeJob.
  class SeoSpamCheckJob < ApplicationJob
    sidekiq_options retry: false

    def perform(user_id)
      user = User.find_by(id: user_id)
      return if user.blank? || !user.show_bikes? || user.banned?

      ban_for_seo_spam(user) if SpamEstimator::User.estimate_user(user) > SpamEstimator::User::MARK_SPAM_PERCENT
    end

    private

    def ban_for_seo_spam(user)
      # UserBan#update_user_on_create bans the user and flags their bikes
      UserBan.create(user:, reason: :seo_spam)
    end
  end
end
