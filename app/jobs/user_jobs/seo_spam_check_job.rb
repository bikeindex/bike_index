module UserJobs
  # Bans a likely SEO-spam public-profile (show_bikes) user — crypto/gambling link
  # farms and gibberish profiles. Run inline from AfterUserChangeJob.
  class SeoSpamCheckJob < ApplicationJob
    sidekiq_options retry: false

    # user can be passed directly (e.g. from AfterUserChangeJob, which is already backgrounded)
    def perform(user_id, user = nil)
      user ||= User.find_by(id: user_id)
      return if user.blank? || !user.show_bikes? || user.banned?

      estimate = SpamEstimator::User.estimate(user)
      return unless estimate > SpamEstimator::User::MARK_SPAM_PERCENT

      # UserBan#update_user_on_create bans the user and flags their bikes
      UserBan.create(user:, reason: :seo_spam, description: ban_description(user, estimate))
    end

    private

    # admin truncates this to 100 characters, so lead with the score
    def ban_description(user, estimate)
      matches = SpamEstimator::User.seo_spam_matches(user)
        .map { |term, count| (count > 1) ? "#{term} (#{count})" : term }

      ["Estimate #{estimate.round}", matches.any? ? "matched: #{matches.join(", ")}" : nil]
        .compact.join(". ")
    end
  end
end
