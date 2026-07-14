module Users
  # Flags a likely SEO-spam public-profile (show_bikes) user — crypto/gambling link
  # farms and gibberish profiles — with an EmailBan. Enqueued from AfterUserChangeJob.
  class SeoSpamCheckJob < ApplicationJob
    sidekiq_options retry: false

    # crypto and gambling terms that SEO-spam profiles exist to promote
    SEO_SPAM_REGEX = /\b(?:
      bitcoin | btc | ethereum | crypto(?:currency|\s?wallet)? | blockchain | binance |
      coinbase | dogecoin | altcoin | memecoin | defi | web3 | metamask | airdrop |
      presale | usdt | tether |
      casino | gambling | roulette | blackjack | baccarat | poker | sportsbook |
      jackpot | judi | togel | situs | gacor | bandar | slot\s?(?:gacor|online|88) |
      bet365 | betting | wager
    )\b/xi

    def perform(user_id)
      user = User.find_by(id: user_id)
      return if user.blank? || !user.show_bikes? || user.banned? || user.email_banned?

      EmailBan.create(user:, reason: :seo_spam) if seo_spam?(user)
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
