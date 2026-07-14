module Users
  # Weekly sweep of public-profile (show_bikes) users, flagging likely SEO-spam
  # accounts — crypto/gambling link farms and gibberish profiles — with an EmailBan.
  class SeoSpamCheckJob < ScheduledJob
    prepend ScheduledJobRecorder

    SEO_SPAM_CHECK_LIMIT = 1000

    # crypto and gambling terms that SEO-spam profiles exist to promote
    SEO_SPAM_REGEX = /\b(?:
      bitcoin | btc | ethereum | crypto(?:currency|\s?wallet)? | blockchain | binance |
      coinbase | dogecoin | altcoin | memecoin | defi | web3 | metamask | airdrop |
      presale | usdt | tether |
      casino | gambling | roulette | blackjack | baccarat | poker | sportsbook |
      jackpot | judi | togel | situs | gacor | bandar | slot\s?(?:gacor|online|88) |
      bet365 | betting | wager
    )\b/xi

    def self.frequency
      1.week
    end

    def perform(user_id = nil)
      return enqueue_workers if user_id.blank?

      user = User.find_by(id: user_id)
      return if user.blank? || !user.show_bikes? || user.banned? || user.email_banned?

      EmailBan.create(user:, reason: :seo_spam) if seo_spam?(user)
    end

    def enqueue_workers
      User.where(show_bikes: true).order(Arel.sql("RANDOM()"))
        .limit(SEO_SPAM_CHECK_LIMIT).pluck(:id)
        .each { |id| self.class.perform_async(id) }
    end

    def seo_spam?(user)
      seo_spam_references?(user) || spammy_profile_text?(user)
    end

    private

    # crypto/gambling references anywhere in the public profile, including link URLs
    def seo_spam_references?(user)
      scannable_strings(user).any? { |str| str.match?(SEO_SPAM_REGEX) }
    end

    # the existing estimator, run over free-text fields only (URLs/handles score as
    # gibberish and would false-positive)
    def spammy_profile_text?(user)
      text = [user.name, user.title, user.description].select(&:present?).join(" ")
      text.present? && SpamEstimator.string_spaminess(text) > SpamEstimator::MARK_SPAM_PERCENT
    end

    def scannable_strings(user)
      [user.name, user.title, user.description, user.username, user.mb_link_title,
        user.mb_link_target, user.twitter, user.instagram].select(&:present?)
    end
  end
end
