module SpamEstimator
  module User
    extend Functionable

    MARK_SPAM_PERCENT = 90 # May modify in the future!

    # crypto and gambling terms that SEO-spam profiles exist to promote
    SEO_SPAM_REGEX = /\b(?:
      bitcoin | btc | ethereum | crypto(?:currency|\s?wallet)? | blockchain | binance |
      coinbase | dogecoin | altcoin | memecoin | defi | web3 | metamask | airdrop |
      presale | usdt | tether |
      casino | gambling | roulette | blackjack | baccarat | poker | sportsbook |
      jackpot | judi | togel | situs | gacor | bandar | slot\s?(?:gacor|online|88) |
      bet365 | betting | wager
    )\b/xi

    def estimate_user(user)
      return 0 if user.blank?

      # a crypto/gambling reference anywhere in the profile is a definite signal
      estimate = seo_spam_references?(user) ? 100 : spammy_text_estimate(user)

      (estimate - bike_ownership_reduction(user)).clamp(0, 100)
    end

    #
    # private below here
    #

    # references anywhere in the public profile, including link URLs and handles
    def seo_spam_references?(user)
      scannable_strings(user).any? { |str| str.match?(SEO_SPAM_REGEX) }
    end

    # description and title are the SEO-spam payload; weight them far above name/username
    # (URLs/handles are only regex-scanned above — the estimator scores them as gibberish)
    def spammy_text_estimate(user)
      heavy = Text.estimate([user.description, user.title].select(&:present?).join(" "))
      light = Text.estimate([user.name, user.username].select(&:present?).join(" "))

      heavy + 0.2 * light
    end

    def scannable_strings(user)
      [user.name, user.title, user.description, user.username, user.mb_link_title,
        user.mb_link_target, user.twitter, user.instagram].select(&:present?)
    end

    # real registrations are strong evidence against spam
    def bike_ownership_reduction(user)
      case user.bikes.limit(2).count
      when 0 then 0
      when 1 then 30
      else 50
      end
    end

    conceal :seo_spam_references?, :spammy_text_estimate, :scannable_strings, :bike_ownership_reduction
  end
end
