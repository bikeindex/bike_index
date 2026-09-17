module SpamEstimator
  module User
    extend Functionable

    MARK_SPAM_PERCENT = 90 # May modify in the future!

    def estimate(user)
      return 0 if user.blank?

      # each spam-term reference is a strong signal, stacked onto the text score
      score = spammy_text_estimate(user) + 30 * seo_spam_reference_count(user) +
        promotional_link_estimate(user)

      (score - bike_ownership_reduction(user)).clamp(0, 100)
    end

    def seo_spam_matches(user) = Text.seo_spam_matches(scannable_text(user))

    #
    # private below here
    #

    def seo_spam_reference_count(user)
      seo_spam_matches(user).values.sum
    end

    # includes link URLs and handles, where terms show up even when the prose is clean
    def scannable_text(user)
      return "" if user.blank?

      [user.name, user.title, user.description, user.username, user.mb_link_title,
        user.mb_link_target, user.twitter, user.instagram].join(" ")
    end

    # description and title are the SEO-spam payload; weight them far above name/username
    # (URLs/handles are only regex-scanned above — the estimator scores them as gibberish)
    def spammy_text_estimate(user)
      heavy = Text.estimate([user.description, user.title].select(&:present?).join(" "))
      light = Text.estimate([user.name, user.username].select(&:present?).join(" "))

      heavy + 0.2 * light
    end

    # SEO farms exist to host the link — registering bikes is what separates them from riders,
    # so ownership below more than cancels this out
    def promotional_link_estimate(user)
      user.mb_link_target.present? ? 50 : 0
    end

    # real registrations are strong evidence against spam — but only real ones,
    # otherwise a junk registration buys the reduction that cancels the link above
    def bike_ownership_reduction(user)
      case user.bikes.not_spam.limit(2).count
      when 0 then 0
      when 1 then 40
      else 80
      end
    end

    conceal :seo_spam_reference_count, :scannable_text, :spammy_text_estimate,
      :promotional_link_estimate, :bike_ownership_reduction
  end
end
